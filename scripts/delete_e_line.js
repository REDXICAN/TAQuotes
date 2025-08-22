const admin = require('firebase-admin');
const readline = require('readline');

// Initialize Firebase Admin SDK
// You'll need to download a service account key from Firebase Console
// and save it as firebase-admin-key.json in the project root
let serviceAccount;
try {
  serviceAccount = require('../firebase-admin-key.json');
} catch (error) {
  console.error('❌ Error: firebase-admin-key.json not found in project root');
  console.error('Please download the service account key from Firebase Console:');
  console.error('1. Go to Firebase Console > Project Settings > Service Accounts');
  console.error('2. Click "Generate new private key"');
  console.error('3. Save the file as firebase-admin-key.json in the project root');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://taquotes-default-rtdb.firebaseio.com'
});

const db = admin.database();

async function deleteELineProducts() {
  console.log('🔍 Fetching all products from database...');
  
  try {
    // Get all products
    const snapshot = await db.ref('products').once('value');
    const productsData = snapshot.val();
    
    if (!productsData) {
      console.log('❌ No products found in database');
      return;
    }
    
    console.log(`✅ Found ${Object.keys(productsData).length} total products\n`);
    
    // Find E line products
    const eLineProducts = {};
    
    Object.entries(productsData).forEach(([key, product]) => {
      const sku = product.sku || '';
      const model = product.model || '';
      const name = product.name || '';
      const productType = product.productType || '';
      
      // Check if it's an E line product
      if (sku.endsWith('-E') || 
          sku.includes('E-') ||
          model.endsWith('-E') || 
          model.includes('E-') ||
          productType.toLowerCase().includes('e series') ||
          productType.toLowerCase().includes('e-series') ||
          name.toLowerCase().includes('e series') ||
          name.toLowerCase().includes('e-series')) {
        eLineProducts[key] = product;
      }
    });
    
    if (Object.keys(eLineProducts).length === 0) {
      console.log('✅ No E line products found in database');
      return;
    }
    
    console.log(`🔍 Found ${Object.keys(eLineProducts).length} E line products:\n`);
    
    // List E line products
    let index = 1;
    Object.entries(eLineProducts).forEach(([key, product]) => {
      console.log(`${index}. SKU: ${product.sku} | Model: ${product.model} | Name: ${product.name}`);
      index++;
    });
    
    console.log(`\n⚠️  WARNING: This will permanently delete ${Object.keys(eLineProducts).length} E line products!`);
    console.log('Type "DELETE" to confirm deletion, or press Enter to cancel:');
    
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout
    });
    
    const confirmation = await new Promise(resolve => {
      rl.question('', answer => {
        rl.close();
        resolve(answer.trim());
      });
    });
    
    if (confirmation.toUpperCase() !== 'DELETE') {
      console.log('❌ Deletion cancelled');
      return;
    }
    
    console.log('\n🗑️  Deleting E line products...');
    
    // Delete each E line product
    let deleted = 0;
    let failed = 0;
    
    for (const key of Object.keys(eLineProducts)) {
      try {
        await db.ref(`products/${key}`).remove();
        deleted++;
        console.log(`  ✅ Deleted product with key: ${key}`);
      } catch (error) {
        failed++;
        console.log(`  ❌ Failed to delete product with key: ${key} - Error: ${error.message}`);
      }
    }
    
    console.log('\n📊 Deletion Summary:');
    console.log(`  ✅ Successfully deleted: ${deleted} products`);
    if (failed > 0) {
      console.log(`  ❌ Failed to delete: ${failed} products`);
    }
    
    // Verify remaining products
    const verifySnapshot = await db.ref('products').once('value');
    const remainingProducts = verifySnapshot.val() || {};
    console.log(`\n📊 Database now contains ${Object.keys(remainingProducts).length} products`);
    
    // Double-check no E line products remain
    let remainingELine = 0;
    Object.values(remainingProducts).forEach(product => {
      const sku = product.sku || '';
      const model = product.model || '';
      if (sku.endsWith('-E') || sku.includes('E-') || 
          model.endsWith('-E') || model.includes('E-')) {
        remainingELine++;
      }
    });
    
    if (remainingELine > 0) {
      console.log(`  ⚠️  Warning: ${remainingELine} E line products may still remain`);
    } else {
      console.log('  ✅ All E line products successfully removed');
    }
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    process.exit(0);
  }
}

deleteELineProducts();