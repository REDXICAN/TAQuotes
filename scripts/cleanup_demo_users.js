// Script to remove demo/test users from Firebase Realtime Database
// Run with: node scripts/cleanup_demo_users.js

const admin = require('firebase-admin');
const serviceAccount = require('../firebase-admin-key.json'); // You'll need to download this from Firebase Console

// Initialize admin SDK
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://taquotes-default-rtdb.firebaseio.com"
});

const db = admin.database();

async function cleanupDemoUsers() {
  console.log('========================================');
  console.log('    Firebase Demo Users Cleanup');
  console.log('========================================\n');

  try {
    // Get all users from user_profiles
    const snapshot = await db.ref('user_profiles').once('value');
    const users = snapshot.val() || {};
    
    console.log(`Found ${Object.keys(users).length} total users\n`);
    
    const demoUsers = [];
    const realUsers = [];
    
    // Identify demo users (common patterns)
    const demoPatterns = [
      /test/i,
      /demo/i,
      /example/i,
      /sample/i,
      /temp/i,
      /trial/i,
      /^user\d+@/i,  // user1@, user2@, etc.
      /^a+@/i,       // aaa@, aa@, etc.
      /^test\d+/i,   // test1, test2, etc.
      /@test\./i,    // @test.com
      /@example\./i, // @example.com
      /@demo\./i,    // @demo.com
      /^asdf/i,      // asdf, asdfasdf, etc.
      /^qwerty/i,    // qwerty patterns
      /^abc@/i,      // abc@
      /^123@/i,      // 123@
    ];
    
    // Check each user
    for (const [uid, userData] of Object.entries(users)) {
      const email = userData.email || '';
      const name = userData.name || '';
      const displayName = userData.displayName || '';
      
      // Check if this matches demo patterns
      let isDemo = false;
      for (const pattern of demoPatterns) {
        if (pattern.test(email) || pattern.test(name) || pattern.test(displayName)) {
          isDemo = true;
          break;
        }
      }
      
      // Also check if created recently with suspicious patterns
      const createdAt = userData.createdAt || userData.created_at;
      const daysSinceCreation = createdAt ? 
        (Date.now() - new Date(createdAt).getTime()) / (1000 * 60 * 60 * 24) : 
        999;
      
      // If very short email or name, likely demo
      if (email.length < 5 || (email.split('@')[0] || '').length < 3) {
        isDemo = true;
      }
      
      if (isDemo) {
        demoUsers.push({ uid, email, name });
      } else {
        realUsers.push({ uid, email, name });
      }
    }
    
    console.log(`📊 Analysis Results:`);
    console.log(`  • Real users: ${realUsers.length}`);
    console.log(`  • Demo users to remove: ${demoUsers.length}\n`);
    
    if (demoUsers.length > 0) {
      console.log('Demo users found:');
      demoUsers.forEach(user => {
        console.log(`  - ${user.email || 'No email'} (${user.name || 'No name'})`);
      });
      
      console.log('\n⚠️  This will also delete:');
      console.log('  • All quotes created by these users');
      console.log('  • All clients created by these users');
      console.log('  • All cart items for these users\n');
      
      // Create backup first
      const backup = {
        timestamp: new Date().toISOString(),
        users: demoUsers,
        totalRemoved: demoUsers.length
      };
      
      // Save backup
      const fs = require('fs');
      const backupFile = `demo_users_backup_${Date.now()}.json`;
      fs.writeFileSync(backupFile, JSON.stringify(backup, null, 2));
      console.log(`✅ Backup saved to: ${backupFile}\n`);
      
      // Ask for confirmation
      const readline = require('readline').createInterface({
        input: process.stdin,
        output: process.stdout
      });
      
      readline.question('Do you want to proceed with deletion? (yes/no): ', async (answer) => {
        if (answer.toLowerCase() === 'yes') {
          console.log('\n🗑️  Deleting demo users and their data...\n');
          
          for (const user of demoUsers) {
            try {
              // Delete user profile
              await db.ref(`user_profiles/${user.uid}`).remove();
              
              // Delete user's quotes
              await db.ref(`quotes/${user.uid}`).remove();
              
              // Delete user's clients
              await db.ref(`clients/${user.uid}`).remove();
              
              // Delete user's cart
              await db.ref(`cart_items/${user.uid}`).remove();
              
              // Try to delete from Firebase Auth too
              try {
                await admin.auth().deleteUser(user.uid);
                console.log(`  ✅ Deleted: ${user.email || user.uid}`);
              } catch (authError) {
                console.log(`  ⚠️  Deleted data for: ${user.email || user.uid} (Auth deletion failed)`);
              }
            } catch (error) {
              console.log(`  ❌ Failed to delete: ${user.email || user.uid} - ${error.message}`);
            }
          }
          
          console.log('\n✅ Cleanup complete!');
          console.log(`  • Removed ${demoUsers.length} demo users`);
          console.log(`  • Kept ${realUsers.length} real users`);
        } else {
          console.log('\n❌ Cleanup cancelled');
        }
        
        readline.close();
        process.exit(0);
      });
    } else {
      console.log('✅ No demo users found - database is clean!');
      process.exit(0);
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

// Also keep important users
const KEEP_USERS = [
  'andres@turboairmexico.com',
  'turboairquotes@gmail.com',
  // Add other important emails here
];

cleanupDemoUsers();