// Firebase Cloud Function to set user roles as custom claims
// This function should be deployed to Firebase Functions

const { onCall } = require('firebase-functions/v2/https');
const { getAuth } = require('firebase-admin/auth');
const { getDatabase } = require('firebase-admin/database');
const { initializeApp } = require('firebase-admin/app');

// Initialize Firebase Admin (if not already initialized)
try {
  initializeApp();
} catch (e) {
  // Already initialized
}

/**
 * Cloud Function to set user role claims
 * Only SuperAdmin can modify roles
 */
exports.setUserRole = onCall(async (request) => {
  const { auth, data } = request;

  // Verify caller is authenticated
  if (!auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated');
  }

  // Check if caller is SuperAdmin
  const callerEmail = auth.token.email;
  if (callerEmail !== 'andres@turboairmexico.com' && auth.token.role !== 'superadmin') {
    throw new HttpsError('permission-denied', 'Only SuperAdmin can modify user roles');
  }

  const { userId, role } = data;

  // Validate input
  if (!userId || !role) {
    throw new HttpsError('invalid-argument', 'userId and role are required');
  }

  const validRoles = ['superadmin', 'admin', 'sales', 'distributor'];
  if (!validRoles.includes(role)) {
    throw new HttpsError('invalid-argument', `Invalid role. Must be one of: ${validRoles.join(', ')}`);
  }

  try {
    // Set custom claims
    await getAuth().setCustomUserClaims(userId, { role });

    // Update user record in database
    const db = getDatabase();
    await db.ref(`users/${userId}`).update({
      role,
      updated_at: new Date().toISOString(),
      updated_by: auth.uid,
    });

    console.log(`Role '${role}' set for user ${userId} by ${auth.uid}`);

    return {
      success: true,
      message: `Role '${role}' successfully set for user`,
      userId,
      role,
    };
  } catch (error) {
    console.error('Error setting user role:', error);
    throw new HttpsError('internal', 'Failed to set user role');
  }
});

/**
 * Cloud Function to initialize SuperAdmin role
 * Sets custom claims for the SuperAdmin email
 */
exports.initializeSuperAdmin = onCall(async (request) => {
  const superAdminEmail = 'andres@turboairmexico.com';

  try {
    // Get user by email
    const userRecord = await getAuth().getUserByEmail(superAdminEmail);

    // Set SuperAdmin custom claims
    await getAuth().setCustomUserClaims(userRecord.uid, {
      role: 'superadmin',
      isSuperAdmin: true
    });

    // Update database record
    const db = getDatabase();
    await db.ref(`users/${userRecord.uid}`).update({
      role: 'superadmin',
      email: superAdminEmail,
      updated_at: new Date().toISOString(),
      updated_by: 'system',
    });

    console.log(`SuperAdmin role initialized for ${superAdminEmail}`);

    return {
      success: true,
      message: 'SuperAdmin role initialized successfully',
      userId: userRecord.uid,
      email: superAdminEmail,
    };
  } catch (error) {
    console.error('Error initializing SuperAdmin:', error);
    throw new HttpsError('internal', 'Failed to initialize SuperAdmin role');
  }
});

/**
 * Cloud Function to get user role information
 */
exports.getUserRole = onCall(async (request) => {
  const { auth, data } = request;

  if (!auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { userId } = data;
  const targetUserId = userId || auth.uid;

  // Users can only get their own role unless they're admin+
  if (targetUserId !== auth.uid &&
      auth.token.role !== 'superadmin' &&
      auth.token.role !== 'admin' &&
      auth.token.email !== 'andres@turboairmexico.com') {
    throw new HttpsError('permission-denied', 'Insufficient permissions to view user role');
  }

  try {
    const userRecord = await getAuth().getUser(targetUserId);
    const customClaims = userRecord.customClaims || {};

    // Get role from database as fallback
    const db = getDatabase();
    const userSnapshot = await db.ref(`users/${targetUserId}`).once('value');
    const userData = userSnapshot.val() || {};

    const role = customClaims.role || userData.role || 'distributor';

    return {
      success: true,
      userId: targetUserId,
      email: userRecord.email,
      role,
      customClaims,
      lastSignInTime: userRecord.metadata.lastSignInTime,
      creationTime: userRecord.metadata.creationTime,
    };
  } catch (error) {
    console.error('Error getting user role:', error);
    throw new HttpsError('internal', 'Failed to get user role');
  }
});

/**
 * Cloud Function that runs on user creation to set default role
 */
const { beforeUserCreated } = require('firebase-functions/v2/identity');

exports.onUserCreate = beforeUserCreated((event) => {
  const { email } = event.data;

  // Auto-assign SuperAdmin role to the specific email
  if (email === 'andres@turboairmexico.com') {
    return {
      customClaims: {
        role: 'superadmin',
        isSuperAdmin: true,
      }
    };
  }

  // Default role for all other users
  return {
    customClaims: {
      role: 'distributor',
    }
  };
});

/**
 * Cloud Function to batch update user roles from database
 * Useful for migrating existing users to custom claims
 */
exports.syncUserRoles = onCall(async (request) => {
  const { auth } = request;

  // Only SuperAdmin can run this function
  if (!auth || (auth.token.email !== 'andres@turboairmexico.com' && auth.token.role !== 'superadmin')) {
    throw new HttpsError('permission-denied', 'Only SuperAdmin can sync user roles');
  }

  try {
    const db = getDatabase();
    const usersSnapshot = await db.ref('users').once('value');
    const users = usersSnapshot.val() || {};

    const results = [];

    for (const [userId, userData] of Object.entries(users)) {
      const role = userData.role || 'distributor';

      try {
        await getAuth().setCustomUserClaims(userId, { role });
        results.push({ userId, email: userData.email, role, status: 'success' });
        console.log(`Synced role '${role}' for user ${userId}`);
      } catch (error) {
        results.push({ userId, email: userData.email, role, status: 'error', error: error.message });
        console.error(`Failed to sync role for user ${userId}:`, error);
      }
    }

    return {
      success: true,
      message: 'User role sync completed',
      results,
      totalUsers: results.length,
      successCount: results.filter(r => r.status === 'success').length,
      errorCount: results.filter(r => r.status === 'error').length,
    };
  } catch (error) {
    console.error('Error syncing user roles:', error);
    throw new HttpsError('internal', 'Failed to sync user roles');
  }
});