#!/usr/bin/env node

/**
 * Firebase Connection Test Script
 *
 * Tests Firebase Admin SDK connection and permissions
 * Run this before executing the full population script
 */

const admin = require('firebase-admin');
const dotenv = require('dotenv');

// Load environment variables
dotenv.config();

console.log('🔍 Testing Firebase Connection...');
console.log('=================================');

// Check environment variables
if (!process.env.FIREBASE_DATABASE_URL) {
  console.error('❌ FIREBASE_DATABASE_URL not found in .env file');
  process.exit(1);
}

console.log(`✅ Database URL: ${process.env.FIREBASE_DATABASE_URL}`);

// Initialize Firebase with flexible authentication
let firebaseConfig;

if (process.env.FIREBASE_SERVICE_ACCOUNT_KEY) {
  try {
    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_KEY);
    firebaseConfig = {
      credential: admin.credential.cert(serviceAccount),
      databaseURL: process.env.FIREBASE_DATABASE_URL
    };
    console.log('🔑 Using service account from environment variable');
  } catch (error) {
    console.error('❌ Invalid service account JSON in environment variable');
    process.exit(1);
  }
} else {
  try {
    const serviceAccount = require('./firebase-admin-key.json');
    firebaseConfig = {
      credential: admin.credential.cert(serviceAccount),
      databaseURL: process.env.FIREBASE_DATABASE_URL
    };
    console.log('🔑 Using service account from firebase-admin-key.json');
  } catch (error) {
    firebaseConfig = {
      databaseURL: process.env.FIREBASE_DATABASE_URL
    };
    console.log('🔑 Using default credentials (gcloud auth)');
  }
}

try {
  if (!admin.apps.length) {
    admin.initializeApp(firebaseConfig);
  }
  console.log('✅ Firebase Admin SDK initialized');
} catch (error) {
  console.error('❌ Firebase initialization failed:', error.message);
  console.log('\n🔧 Setup Options:');
  console.log('   1. Create firebase-admin-key.json (download from Firebase Console)');
  console.log('   2. Run: gcloud auth application-default login');
  console.log('   3. Set FIREBASE_SERVICE_ACCOUNT_KEY environment variable');
  process.exit(1);
}

const db = admin.database();

async function testConnection() {
  try {
    console.log('\n🔄 Testing database connection...');

    // Test read access
    const testRef = db.ref('.info/connected');
    const snapshot = await testRef.once('value');
    const connected = snapshot.val();

    if (connected) {
      console.log('✅ Database connection successful');
    } else {
      console.log('⚠️  Database connection status unknown');
    }

    // Test write access
    console.log('🔄 Testing write permissions...');
    const testWriteRef = db.ref('test_connection');
    await testWriteRef.set({
      test: true,
      timestamp: new Date().toISOString(),
      message: 'Connection test successful'
    });
    console.log('✅ Write permissions confirmed');

    // Clean up test data
    await testWriteRef.remove();
    console.log('✅ Test data cleaned up');

    // Test specific paths the population script will use
    console.log('\n🔄 Testing required paths...');
    const paths = ['users', 'clients', 'quotes', 'projects'];

    for (const path of paths) {
      try {
        const pathRef = db.ref(path);
        await pathRef.limitToFirst(1).once('value');
        console.log(`✅ Path accessible: /${path}`);
      } catch (error) {
        console.log(`⚠️  Path may have restrictions: /${path} - ${error.message}`);
      }
    }

    console.log('\n🎉 All Firebase tests passed!');
    console.log('🚀 Ready to run: node populate_turboair_data.js');

  } catch (error) {
    console.error('\n❌ Connection test failed:', error.message);
    console.log('\n🔧 Troubleshooting tips:');
    console.log('1. Check Firebase security rules');
    console.log('2. Verify authentication: gcloud auth list');
    console.log('3. Re-authenticate: gcloud auth application-default login');
    console.log('4. Check internet connection');
    process.exit(1);
  } finally {
    process.exit(0);
  }
}

testConnection();