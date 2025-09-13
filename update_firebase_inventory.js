const admin = require('firebase-admin');
const fs = require('fs');

// Initialize Firebase Admin
// You'll need to download the service account key from Firebase Console
// Go to Project Settings > Service Accounts > Generate New Private Key
const serviceAccount = require('./firebase-admin-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://taquotes-default-rtdb.firebaseio.com'
});

const db = admin.database();

// Load inventory data
const inventoryData = JSON.parse(fs.readFileSync('firebase_inventory_update.json', 'utf8'));

console.log(`Starting update of ${Object.keys(inventoryData).length} products...`);

async function updateInventory() {
  const updates = {};
  let count = 0;
  
  for (const [sku, data] of Object.entries(inventoryData)) {
    // Prepare the warehouse stock data
    const warehouseStock = {};
    for (const [warehouse, stock] of Object.entries(data.warehouseStock)) {
      warehouseStock[warehouse] = {
        available: stock.available,
        reserved: stock.reserved,
        lastUpdate: admin.database.ServerValue.TIMESTAMP
      };
    }
    
    // Add to updates batch
    updates[`/products/${sku}/warehouseStock`] = warehouseStock;
    updates[`/products/${sku}/totalStock`] = data.totalStock;
    updates[`/products/${sku}/availableStock`] = data.availableStock;
    
    count++;
    
    // Process in batches of 100
    if (count % 100 === 0) {
      console.log(`Processing batch ${count/100}...`);
      await db.ref().update(updates);
      // Clear updates for next batch
      for (const key in updates) delete updates[key];
    }
  }
  
  // Process remaining updates
  if (Object.keys(updates).length > 0) {
    console.log('Processing final batch...');
    await db.ref().update(updates);
  }
  
  console.log('✅ Inventory update complete!');
  console.log(`Updated ${count} products with warehouse stock information.`);
  process.exit(0);
}

updateInventory().catch(error => {
  console.error('❌ Error updating inventory:', error);
  process.exit(1);
});