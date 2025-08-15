const XLSX = require('xlsx');
const https = require('https');
const fs = require('fs');
const path = require('path');

// Firebase configuration
const FIREBASE_DATABASE_URL = 'https://turbo-air-viewer-default-rtdb.firebaseio.com';

// Function to parse price
function parsePrice(priceStr) {
    if (!priceStr) return 0;
    if (typeof priceStr === 'number') return priceStr;
    const cleaned = String(priceStr).replace(/[$,]/g, '').trim();
    return parseFloat(cleaned) || 0;
}

// Function to parse integer
function parseIntSafely(value) {
    if (!value) return null;
    if (typeof value === 'number') return Math.floor(value);
    const cleaned = String(value).replace(/\D/g, '');
    return cleaned ? parseInt(cleaned) : null;
}

// Function to upload data to Firebase
function uploadToFirebase(data) {
    return new Promise((resolve, reject) => {
        const jsonData = JSON.stringify(data);
        
        const options = {
            hostname: 'turbo-air-viewer-default-rtdb.firebaseio.com',
            path: '/products.json',
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(jsonData)
            }
        };
        
        const req = https.request(options, (res) => {
            let responseData = '';
            
            res.on('data', (chunk) => {
                responseData += chunk;
            });
            
            res.on('end', () => {
                if (res.statusCode === 200) {
                    console.log('Successfully uploaded to Firebase!');
                    resolve(JSON.parse(responseData));
                } else {
                    console.error('Firebase error:', res.statusCode, responseData);
                    reject(new Error(`Firebase returned ${res.statusCode}: ${responseData}`));
                }
            });
        });
        
        req.on('error', (error) => {
            console.error('Request error:', error);
            reject(error);
        });
        
        req.write(jsonData);
        req.end();
    });
}

// Main function
async function uploadExcelToFirebase() {
    try {
        const excelPath = 'D:\\OneDrive\\Documentos\\-- TurboAir\\7 Bots\\Turbots\\-- Flutter App\\turbo_air_products.xlsx';
        
        console.log('Reading Excel file:', excelPath);
        
        // Read the Excel file
        const workbook = XLSX.readFile(excelPath);
        const sheetName = workbook.SheetNames[0];
        const worksheet = workbook.Sheets[sheetName];
        const data = XLSX.utils.sheet_to_json(worksheet);
        
        console.log(`Found ${data.length} rows in Excel`);
        
        const products = {};
        let processedCount = 0;
        
        // Process each row
        data.forEach((row, index) => {
            if (!row.SKU) return; // Skip rows without SKU
            
            const sku = String(row.SKU).trim();
            const description = row.Description ? String(row.Description).trim() : '';
            const name = description ? description.split(',')[0].trim() : sku;
            
            const productData = {
                sku: sku,
                model: sku,
                name: name,
                displayName: name,
                description: description,
                category: row.Category ? String(row.Category).trim() : '',
                subcategory: row.Subcategory ? String(row.Subcategory).trim() : '',
                product_type: row['Product Type'] ? String(row['Product Type']).trim() : '',
                voltage: row.Voltage ? String(row.Voltage).trim() : '',
                amperage: row.Amperage ? String(row.Amperage).trim() : '',
                phase: row.Phase ? String(row.Phase).trim() : '',
                frequency: row.Frequency ? String(row.Frequency).trim() : '',
                plug_type: row['Plug Type'] ? String(row['Plug Type']).trim() : '',
                dimensions: row.Dimensions ? String(row.Dimensions).trim() : '',
                dimensions_metric: row['Dimensions (Metric)'] ? String(row['Dimensions (Metric)']).trim() : '',
                weight: row.Weight ? String(row.Weight).trim() : '',
                weight_metric: row['Weight (Metric)'] ? String(row['Weight (Metric)']).trim() : '',
                temperature_range: row['Temperature Range'] ? String(row['Temperature Range']).trim() : '',
                temperature_range_metric: row['Temperature Range (Metric)'] ? String(row['Temperature Range (Metric)']).trim() : '',
                refrigerant: row.Refrigerant ? String(row.Refrigerant).trim() : '',
                compressor: row.Compressor ? String(row.Compressor).trim() : '',
                capacity: row.Capacity ? String(row.Capacity).trim() : '',
                features: row.Features ? String(row.Features).trim() : '',
                certifications: row.Certifications ? String(row.Certifications).trim() : '',
                price: parsePrice(row.Price),
                stock: 100,
                image_url: `assets/screenshots/${sku}/P.1.png`,
                created_at: new Date().toISOString(),
                updated_at: new Date().toISOString()
            };
            
            // Add doors and shelves if present
            const doors = parseIntSafely(row.Doors);
            if (doors !== null) productData.doors = doors;
            
            const shelves = parseIntSafely(row.Shelves);
            if (shelves !== null) productData.shelves = shelves;
            
            // Remove empty strings
            Object.keys(productData).forEach(key => {
                if (productData[key] === '') delete productData[key];
            });
            
            // Generate unique key
            const firebaseKey = `product_${String(index).padStart(4, '0')}`;
            products[firebaseKey] = productData;
            
            processedCount++;
            console.log(`Processed: ${sku} - ${name}`);
        });
        
        console.log(`\nTotal products processed: ${processedCount}`);
        console.log('Uploading to Firebase...');
        
        // Upload to Firebase
        await uploadToFirebase(products);
        
        console.log('\n✅ Successfully uploaded all products to Firebase!');
        console.log('Products are now available at: https://turbo-air-viewer.web.app');
        
        // Save backup JSON
        const backupPath = path.join(__dirname, 'products_backup.json');
        fs.writeFileSync(backupPath, JSON.stringify(products, null, 2));
        console.log(`\nBackup saved to: ${backupPath}`);
        
    } catch (error) {
        console.error('Error:', error);
    }
}

// Check if xlsx module is installed
try {
    require.resolve('xlsx');
    uploadExcelToFirebase();
} catch (e) {
    console.log('Installing required packages...');
    require('child_process').execSync('npm install xlsx', { stdio: 'inherit' });
    console.log('Packages installed. Please run this script again.');
}