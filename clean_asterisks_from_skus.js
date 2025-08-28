const admin = require('firebase-admin');
const serviceAccount = require('./firebase-admin-key.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://taquotes-default-rtdb.firebaseio.com'
});

const db = admin.database();

async function cleanAsterisksFromSKUs() {
  console.log('Starting to clean asterisks from SKUs...');
  
  try {
    // Get all products
    const snapshot = await db.ref('products').once('value');
    const products = snapshot.val();
    
    if (!products) {
      console.log('No products found');
      return;
    }
    
    let updateCount = 0;
    const updates = {};
    const skuMapping = {}; // Track old SKU to new SKU mapping
    
    // Process each product
    for (const [key, product] of Object.entries(products)) {
      if (product.sku && product.sku.includes('*')) {
        const oldSku = product.sku;
        const newSku = oldSku.replace(/\*/g, ''); // Remove all asterisks
        
        console.log(`Updating SKU: ${oldSku} -> ${newSku}`);
        
        // If the key is the SKU itself (not product_XXX), we need to move the entire product
        if (key === oldSku) {
          // Copy product with new SKU
          updates[`products/${newSku}`] = { ...product, sku: newSku };
          // Mark old one for deletion
          updates[`products/${oldSku}`] = null;
          skuMapping[oldSku] = newSku;
        } else {
          // Just update the SKU field
          updates[`products/${key}/sku`] = newSku;
        }
        
        updateCount++;
      }
    }
    
    if (updateCount === 0) {
      console.log('No SKUs with asterisks found');
      return;
    }
    
    console.log(`Found ${updateCount} SKUs with asterisks`);
    console.log('Applying updates to database...');
    
    // Apply all updates
    await db.ref().update(updates);
    
    console.log('✓ Successfully cleaned asterisks from SKUs');
    console.log(`Updated ${updateCount} products`);
    
    if (Object.keys(skuMapping).length > 0) {
      console.log('\nSKU Mapping (old -> new):');
      for (const [oldSku, newSku] of Object.entries(skuMapping)) {
        console.log(`  ${oldSku} -> ${newSku}`);
      }
    }
    
  } catch (error) {
    console.error('Error cleaning SKUs:', error);
  } finally {
    process.exit();
  }
}

// Run the cleanup
cleanAsterisksFromSKUs();