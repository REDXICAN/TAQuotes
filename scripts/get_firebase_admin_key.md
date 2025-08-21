# How to Get Firebase Admin SDK Key

To run the demo user cleanup script, you need to download the Firebase Admin SDK key:

1. Go to Firebase Console: https://console.firebase.google.com/project/taquotes/settings/serviceaccounts/adminsdk

2. Click on "Generate new private key"

3. Save the downloaded JSON file as `firebase-admin-key.json` in the root of your project (C:\Users\andre\Desktop\-- Flutter App\)

4. Once saved, run: `node scripts/cleanup_demo_users.js`

Note: Keep this file secure and NEVER commit it to git!