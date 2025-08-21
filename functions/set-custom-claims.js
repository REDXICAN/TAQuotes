// Cloud Function to set custom claims for user roles
// Deploy this to Firebase Functions

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize admin if not already done
if (!admin.apps.length) {
  admin.initializeApp();
}

// Function to set custom claims for a user
exports.setUserClaims = functions.https.onCall(async (data, context) => {
  // Check if request is made by an authenticated user
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Request must be authenticated'
    );
  }

  // Check if the requesting user is a super admin
  const callerClaims = context.auth.token;
  if (!callerClaims.superAdmin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only super admins can set user claims'
    );
  }

  const { uid, claims } = data;

  // Validate input
  if (!uid || !claims) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Missing uid or claims'
    );
  }

  // Validate role
  const validRoles = ['admin', 'sales', 'distributor', 'superAdmin'];
  if (claims.role && !validRoles.includes(claims.role)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `Invalid role: ${claims.role}`
    );
  }

  try {
    // Set custom claims
    const customClaims = {};
    
    // Set role-based boolean flags
    if (claims.role === 'superAdmin') {
      customClaims.superAdmin = true;
      customClaims.admin = true;
    } else if (claims.role === 'admin') {
      customClaims.admin = true;
      customClaims.superAdmin = false;
    } else {
      customClaims.admin = false;
      customClaims.superAdmin = false;
    }
    
    customClaims.role = claims.role;

    await admin.auth().setCustomUserClaims(uid, customClaims);

    // Log the action
    await admin.database().ref('audit_logs').push({
      user_id: context.auth.uid,
      action: 'set_custom_claims',
      target_uid: uid,
      claims: customClaims,
      timestamp: admin.database.ServerValue.TIMESTAMP,
    });

    return {
      success: true,
      message: `Custom claims set for user ${uid}`,
    };
  } catch (error) {
    console.error('Error setting custom claims:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to set custom claims'
    );
  }
});

// Function to initialize super admin (run once)
exports.initializeSuperAdmin = functions.https.onRequest(async (req, res) => {
  // IMPORTANT: Secure this endpoint in production!
  // Check for a secret token or remove after initial setup
  
  const secretToken = req.headers['x-init-token'];
  const expectedToken = functions.config().init?.token || 'YOUR_SECRET_TOKEN_HERE';
  
  if (secretToken !== expectedToken) {
    res.status(403).send('Forbidden');
    return;
  }

  const superAdminEmail = 'andres@turboairmexico.com';

  try {
    // Get user by email
    const user = await admin.auth().getUserByEmail(superAdminEmail);
    
    // Set super admin claims
    await admin.auth().setCustomUserClaims(user.uid, {
      superAdmin: true,
      admin: true,
      role: 'superAdmin',
    });

    // Update user profile in database
    await admin.database().ref(`user_profiles/${user.uid}`).update({
      role: 'superAdmin',
      claims_set: true,
      updated_at: admin.database.ServerValue.TIMESTAMP,
    });

    res.json({
      success: true,
      message: `Super admin claims set for ${superAdminEmail}`,
    });
  } catch (error) {
    console.error('Error initializing super admin:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

// Function to verify user claims
exports.verifyUserClaims = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Request must be authenticated'
    );
  }

  const uid = data.uid || context.auth.uid;

  try {
    const user = await admin.auth().getUser(uid);
    
    return {
      uid: user.uid,
      email: user.email,
      customClaims: user.customClaims || {},
    };
  } catch (error) {
    throw new functions.https.HttpsError(
      'internal',
      'Failed to verify user claims'
    );
  }
});