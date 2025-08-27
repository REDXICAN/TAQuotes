const XLSX = require('xlsx');
const fs = require('fs');

// Read the Excel file
const filePath = 'D:\\OneDrive\\Documentos\\-- TurboAir\\7 Bots\\Turbots\\-- Base de Clientes\\Reporte de Ventas x Cliente Agosto 2025.xls';
const workbook = XLSX.readFile(filePath);

// Get the first sheet
const sheetName = workbook.SheetNames[0];
const sheet = workbook.Sheets[sheetName];

// Convert to JSON
const data = XLSX.utils.sheet_to_json(sheet, { header: 1 });

// Extract company names
const companies = new Set();
let currentCompany = null;

for (let i = 0; i < data.length; i++) {
  const row = data[i];
  
  // Look for rows where column 0 says "Nombre:"
  if (row[0] && row[0].toString().trim() === 'Nombre:' && row[1]) {
    currentCompany = row[1].toString().trim();
    // Skip product names and add only company names
    if (currentCompany && 
        !currentCompany.includes('REFRIGERADOR') &&
        !currentCompany.includes('CONGELADOR') &&
        !currentCompany.includes('MESA') &&
        !currentCompany.includes('BASE CHEF') &&
        !currentCompany.includes('GABINETE') &&
        !currentCompany.includes('PUERTA') &&
        !currentCompany.includes('ENFRIADOR') &&
        !currentCompany.includes('BARRA') &&
        !currentCompany.includes('EMPAQUE') &&
        !currentCompany.includes('CHAROLA') &&
        !currentCompany.includes('MOTOR') &&
        !currentCompany.includes('PARRILLA') &&
        !currentCompany.includes('CLIP') &&
        !currentCompany.includes('ANTICIPO') &&
        currentCompany.length > 3) {
      companies.add(currentCompany);
    }
  }
}

// Convert to array and sort
const companyList = Array.from(companies).sort();

console.log(`Found ${companyList.length} companies:\n`);
console.log('='.repeat(80));

// Display companies
companyList.forEach((company, index) => {
  console.log(`${index + 1}. ${company}`);
});

// Create client objects for Firebase
const clientsData = companyList.map(company => ({
  company: company,
  contactName: '',
  email: 'place@holder.com',
  phone: '888-888-8888',
  address: ''
}));

// Save to JSON
fs.writeFileSync('companies_for_firebase.json', JSON.stringify(clientsData, null, 2));

console.log('\n' + '='.repeat(80));
console.log(`\n✅ ${companyList.length} companies extracted and saved to companies_for_firebase.json`);
console.log('\nReview the list above before uploading to Firebase.');
console.log('\nFirebase credentials:');
console.log('- Email: andres@turboairmexico.com');
console.log('- Password: andres123!@#');
console.log('\nEach company will have:');
console.log('- Email: place@holder.com');
console.log('- Phone: 888-888-8888');