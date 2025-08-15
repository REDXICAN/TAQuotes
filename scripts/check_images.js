const fs = require('fs');
const path = require('path');

// Database SKUs from Firebase
const dbSkus = [
  'EUR-28-N6-V',
  'M3F19-1-N',
  'M3F24-1-N',
  'M3H24-1',
  'M3H47-2',
  'M3R19-1-N',
  'M3R24-1-N',
  'M3R24-2-N(-L)',
  'M3R47-2-N',
  'M3R47-4-N(-AL)(-AR)',
  'M3R72-3-N(-AL)(-AR)',
  'M3R72-6-N',
  'MUR-28-N',
  'MUR-72-N',
  'PRO-12R-N(-L)',
  'PRO-15R-N(-L)',
  'PRO-26-2R-N(-L)',
  'PRO-26R-N(-L)',
  'PRO-50R-N',
  'PRO-77-6R-N',
  'PST-28-D2-N',
  'PST-28-G-N(-L)',
  'PST-28-N(-L)',
  'PST-48-D2R(L)-N',
  'PST-48-G-N',
  'PST-48-N',
  'PST-60-G-N',
  'PST-60-N',
  'PST-72-G-N',
  'PST-72-N(-AL)(-AR)',
  'PUR-28-D2-N',
  'PUR-60-G-N',
  'PWR-48-N',
  'TPR-44SD-N',
  'TPR-67SD-N',
  'TPR-93SD-N',
  'TSF-23SD-N(-L)',
  'TSF-49SD-N',
  'TSF-72SD-N',
  'TSR-23GSD-N6',
  'TSR-23SD-N6(-L)',
  'TSR-35GSD-N',
  'TSR-35SD-N6',
  'TSR-49GSD-N',
  'TSR-49SD-N6',
  'TSR-72GSD-N',
  'TSR-72SD-N',
  'TWR-28SD-D2-N'
];

const screenshotsDir = 'D:\\Flutter App\\Turbo-Air-Viewer-Flutter-App\\assets\\screenshots';

// Get all folder names in screenshots directory
const imageFolders = fs.readdirSync(screenshotsDir);

console.log('=== IMAGE MAPPING ANALYSIS ===\n');
console.log('Total DB Products:', dbSkus.length);
console.log('Total Image Folders:', imageFolders.length);
console.log('\n=== MATCHING RESULTS ===\n');

const results = {
  exactMatch: [],
  baseMatch: [],
  partialMatch: [],
  noMatch: []
};

// Check each database SKU
dbSkus.forEach(dbSku => {
  // Check for exact match
  if (imageFolders.includes(dbSku)) {
    results.exactMatch.push(`✅ EXACT: ${dbSku}`);
    return;
  }
  
  // Try without parentheses for variations
  const baseSkuNoParens = dbSku.replace(/\([^)]*\)/g, '');
  if (imageFolders.includes(baseSkuNoParens)) {
    results.baseMatch.push(`🔄 BASE: ${dbSku} → ${baseSkuNoParens}`);
    return;
  }
  
  // Try to find partial matches
  let found = false;
  for (const folder of imageFolders) {
    // Remove variations from both for comparison
    const cleanDbSku = dbSku.replace(/\([^)]*\)/g, '').replace(/-/g, '');
    const cleanFolder = folder.replace(/\([^)]*\)/g, '').replace(/-/g, '');
    
    if (cleanDbSku === cleanFolder) {
      results.partialMatch.push(`🔍 PARTIAL: ${dbSku} → ${folder}`);
      found = true;
      break;
    }
    
    // Check if folder contains the base SKU pattern
    if (folder.includes(baseSkuNoParens)) {
      results.partialMatch.push(`🔍 PARTIAL: ${dbSku} → ${folder}`);
      found = true;
      break;
    }
  }
  
  if (!found) {
    results.noMatch.push(`❌ MISSING: ${dbSku}`);
  }
});

// Print results
console.log('EXACT MATCHES (' + results.exactMatch.length + '):');
results.exactMatch.forEach(m => console.log(m));

console.log('\nBASE MATCHES (' + results.baseMatch.length + '):');
results.baseMatch.forEach(m => console.log(m));

console.log('\nPARTIAL MATCHES (' + results.partialMatch.length + '):');
results.partialMatch.forEach(m => console.log(m));

console.log('\nNO MATCHES - MISSING IMAGES (' + results.noMatch.length + '):');
results.noMatch.forEach(m => console.log(m));

// Summary
console.log('\n=== SUMMARY ===');
console.log(`Total Products: ${dbSkus.length}`);
console.log(`With Images: ${results.exactMatch.length + results.baseMatch.length + results.partialMatch.length}`);
console.log(`Missing Images: ${results.noMatch.length}`);
console.log(`Coverage: ${Math.round((results.exactMatch.length + results.baseMatch.length + results.partialMatch.length) / dbSkus.length * 100)}%`);

// Generate mapping suggestions
console.log('\n=== SUGGESTED IMAGE MAPPINGS ===\n');
const mappings = {};

dbSkus.forEach(dbSku => {
  // Find best match
  if (imageFolders.includes(dbSku)) {
    mappings[dbSku] = dbSku;
  } else {
    const baseSkuNoParens = dbSku.replace(/\([^)]*\)/g, '');
    if (imageFolders.includes(baseSkuNoParens)) {
      mappings[dbSku] = baseSkuNoParens;
    } else {
      // Find closest match
      for (const folder of imageFolders) {
        if (folder.includes(baseSkuNoParens) || folder.startsWith(dbSku.split('-')[0])) {
          mappings[dbSku] = folder;
          break;
        }
      }
    }
  }
});

console.log('Product to Image Folder Mappings:');
Object.entries(mappings).forEach(([sku, folder]) => {
  if (folder) {
    console.log(`  "${sku}": "${folder}",`);
  }
});