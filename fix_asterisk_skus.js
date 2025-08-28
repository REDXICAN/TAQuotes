// Script to remove asterisks from SKUs using Firebase Admin SDK
// This requires firebase-admin-key.json to be present

const skusToFix = [
  "TGF-72SDH*-N",
  "TGF-35SDH*-N", 
  "TGM-15SDH*-N6",
  "TGM-35SDH*-N",
  "TGM-72SDH*-N",
  "TGF-23SDH*-N",
  "TGM-47SD*-N",
  "TGF-47SDH*-N",
  "TGM-15SD*-N6",
  "TGM-47SDH*-N",
  "TGM-23SDH*-N6",
  "TGM-5SD*-N6",
  "TGM-72SD*-N",
  "TGM-20SD*-N6",
  "TGM-7SD*-N6",
  "TGM-35SD*-N",
  "TGM-12SD*-N6",
  "TGM-23SD*-N6",
  "TGM-10SD*-N6"
];

console.log("SKUs to fix:");
skusToFix.forEach(sku => {
  const cleanSku = sku.replace(/\*/g, '');
  console.log(`  ${sku} -> ${cleanSku}`);
});

console.log(`\nTotal SKUs to fix: ${skusToFix.length}`);
console.log("\nTo fix these SKUs manually in Firebase Console:");
console.log("1. Go to https://console.firebase.google.com/project/taquotes/database/taquotes-default-rtdb/data");
console.log("2. Navigate to /products");
console.log("3. For each SKU above:");
console.log("   a. Find the product with asterisk (e.g., TGF-72SDH*-N)");
console.log("   b. Export its data (three dots menu > Export JSON)");
console.log("   c. Delete the product with asterisk");
console.log("   d. Create new product with clean SKU (e.g., TGF-72SDH-N)");
console.log("   e. Import the exported data");
console.log("   f. Update the 'sku' field to remove the asterisk");