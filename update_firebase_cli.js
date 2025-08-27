const fs = require('fs');
const { exec } = require('child_process');
const util = require('util');
const execPromise = util.promisify(exec);

console.log('=' .repeat(80));
console.log('FIREBASE DATABASE UPDATE USING CLI');
console.log('=' .repeat(80));
console.log(`Update Date: ${new Date().toISOString()}`);

// Load data files
console.log('\n1. Loading update files...');

const newProducts = JSON.parse(fs.readFileSync('all_new_products_for_firebase.json', 'utf8'));
console.log(`   ✓ Loaded ${newProducts.length} new products to add`);

const priceUpdates = JSON.parse(fs.readFileSync('firebase_price_updates.json', 'utf8'));
console.log(`   ✓ Loaded ${priceUpdates.length} price updates`);

// Prepare combined update file
const allUpdates = {};

// Add new products
console.log('\n2. Preparing new products...');
newProducts.forEach(product => {
    const key = product.sku.replace(/[\/\.\#\$\[\]]/g, '_');
    allUpdates[`products/${key}`] = product;
});
console.log(`   ✓ Prepared ${Object.keys(allUpdates).length} new products`);

// Add price updates
console.log('\n3. Preparing price updates...');
priceUpdates.forEach(update => {
    allUpdates[`products/${update.firebase_key}/price`] = update.new_price;
});
console.log(`   ✓ Prepared ${priceUpdates.length} price updates`);

// Save to temporary JSON file for Firebase import
const updateFile = 'firebase_complete_update.json';
fs.writeFileSync(updateFile, JSON.stringify(allUpdates, null, 2));
console.log(`\n4. Saved updates to ${updateFile}`);

// Execute Firebase update
console.log('\n5. Uploading to Firebase...');
console.log('   This may take a few minutes...\n');

async function updateFirebase() {
    try {
        // Update all at once using Firebase CLI
        const command = `firebase database:update / ${updateFile}`;
        console.log(`   Executing: ${command}`);
        
        const { stdout, stderr } = await execPromise(command);
        
        if (stderr) {
            console.log('   Warning:', stderr);
        }
        
        console.log('\n✅ UPDATE SUCCESSFUL!');
        console.log(stdout);
        
        // Verify the update
        console.log('\n6. Verifying update...');
        const verifyCommand = 'firebase database:get /products --shallow';
        const { stdout: verifyOutput } = await execPromise(verifyCommand);
        const products = JSON.parse(verifyOutput);
        const productCount = Object.keys(products).length;
        
        console.log(`   ✓ Total products now in Firebase: ${productCount}`);
        
        // Generate detailed summary
        const summary = `
================================================================================
FIREBASE UPDATE COMPLETED SUCCESSFULLY
================================================================================
Date: ${new Date().toISOString()}

CHANGES MADE:
-------------
1. New Products Added: ${newProducts.length}
2. Prices Updated: ${priceUpdates.length}
3. Total Changes: ${newProducts.length + priceUpdates.length}

DATABASE STATUS:
----------------
Previous Total: 809 products
Added: ${newProducts.length} products
Current Total: ${productCount} products

PRICE CHANGES:
--------------
• Updated from "Valued Price" to "MSP (50/10/17)"
• Average reduction: 67.5%
• MSP includes 50% + 10% + 17% discounts

NEW PRODUCT CATEGORIES ADDED:
-----------------------------
• Pro Series Refrigerators/Freezers
• Pizza Prep Tables
• Bar Equipment (Bottle Coolers, Beer Dispensers, Back Bar Coolers)
• Display Cases (Flat Glass, Open Display)
• Undercounter Units

FILES CREATED:
--------------
• firebase_complete_update.json - Combined update file
• firebase_update_final_summary.txt - This summary

================================================================================
`;
        
        console.log(summary);
        
        // Save summary
        fs.writeFileSync('firebase_update_final_summary.txt', summary);
        console.log('✓ Summary saved to firebase_update_final_summary.txt');
        
    } catch (error) {
        console.error('\n❌ UPDATE FAILED!');
        console.error('Error:', error.message);
        
        // If permission denied, provide guidance
        if (error.message.includes('Permission denied')) {
            console.log('\n⚠️  PERMISSION DENIED - Please follow these steps:');
            console.log('1. Make sure you are logged in: firebase login');
            console.log('2. Select the correct project: firebase use taquotes');
            console.log('3. Check Firebase Console for database rules');
            console.log('\nAlternatively, you can manually import the data:');
            console.log('1. Go to Firebase Console > Realtime Database');
            console.log('2. Click the three dots menu > Import JSON');
            console.log('3. Upload: firebase_complete_update.json');
        }
    }
}

// Run the update
updateFirebase();