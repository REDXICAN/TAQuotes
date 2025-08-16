const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
const serviceAccount = {
  "type": "service_account",
  "project_id": "turbo-air-viewer",
  "private_key_id": "your-key-id",
  "private_key": "your-private-key",
  "client_email": "firebase-adminsdk@turbo-air-viewer.iam.gserviceaccount.com",
  "client_id": "your-client-id",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "your-cert-url"
};

// Note: You need to replace the above with actual service account credentials
// For now, let's use the Firebase REST API approach

const fetch = require('node-fetch');

async function createAdminUser() {
  const apiKey = 'AIzaSyByN2I4vjSQO2ptsj8mbkbsqvu94HOtp8c';
  const email = 'andres@turboairmexico.com';
  const password = 'andres123!@#';
  
  try {
    // Try to sign in first
    const signInResponse = await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: email,
          password: password,
          returnSecureToken: true
        })
      }
    );
    
    if (signInResponse.ok) {
      console.log('✅ Admin user already exists and can sign in successfully!');
      const data = await signInResponse.json();
      console.log('User ID:', data.localId);
      return;
    }
    
    // If sign in fails, try to create the user
    const signUpResponse = await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${apiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: email,
          password: password,
          returnSecureToken: true
        })
      }
    );
    
    if (signUpResponse.ok) {
      console.log('✅ Admin user created successfully!');
      const data = await signUpResponse.json();
      console.log('User ID:', data.localId);
    } else {
      const error = await signUpResponse.json();
      console.error('❌ Failed to create user:', error.error.message);
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

// Check products in database
async function checkProducts() {
  try {
    const response = await fetch(
      'https://turbo-air-viewer-default-rtdb.firebaseio.com/products.json?shallow=true'
    );
    
    if (response.ok) {
      const data = await response.json();
      const productCount = data ? Object.keys(data).length : 0;
      console.log(`\n📦 Products in database: ${productCount}`);
      
      if (productCount === 0) {
        console.log('⚠️ No products found! You may need to upload products.');
      }
    } else {
      console.log('❌ Failed to check products');
    }
  } catch (error) {
    console.error('❌ Error checking products:', error);
  }
}

async function main() {
  console.log('🔧 Setting up Turbo Air Viewer Firebase...\n');
  await createAdminUser();
  await checkProducts();
  console.log('\n✅ Setup complete!');
}

main();