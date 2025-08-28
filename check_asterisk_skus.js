const admin = require('firebase-admin');
const serviceAccount = require('./firebase-admin-key.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://taquotes-default-rtdb.firebaseio.com'
});

const db = admin.database();

async function checkAsteriskSKUs() {
  console.log('Checking for SKUs with asterisks...\n');
  
  try {
    // Get all products
    const snapshot = await db.ref('products').once('value');
    const products = snapshot.val();
    
    if (!products) {
      console.log('No products found');
      return;
    }
    
    const skusWithAsterisk = [];
    
    // Check each product
    for (const [key, product] of Object.entries(products)) {
      if (product.sku && product.sku.includes('*')) {
        skusWithAsterisk.push({
          key: key,
          sku: product.sku,
          name: product.name
        });
      }
    }
    
    if (skusWithAsterisk.length === 0) {
      console.log('✓ No SKUs with asterisks found');
    } else {
      console.log(`Found ${skusWithAsterisk.length} SKUs with asterisks:\n`);
      skusWithAsterisk.forEach(item => {
        const cleanSku = item.sku.replace(/\*/g, '');
        console.log(`  Key: ${item.key}`);
        console.log(`  Current SKU: ${item.sku}`);
        console.log(`  Clean SKU: ${cleanSku}`);
        console.log(`  Product: ${item.name}`);
        console.log('  ---');
      });
    }
    
    console.log(`\nTotal products: ${Object.keys(products).length}`);
    console.log(`Products with asterisks: ${skusWithAsterisk.length}`);
    
  } catch (error) {
    console.error('Error checking SKUs:', error);
  } finally {
    process.exit();
  }
}

// Run the check
checkAsteriskSKUs();