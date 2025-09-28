#!/usr/bin/env node

/**
 * TurboAir Sales Data Population Script
 *
 * Populates Firebase with realistic TurboAir sales team data including:
 * - 10 realistic sales team members across Mexico
 * - 3-5 restaurant/hotel clients per user
 * - 2-3 closed quotes and 2-4 in-progress quotes per user
 * - Projects linked to major installations
 * - Spare parts orders
 *
 * Usage: node populate_turboair_data.js
 *
 * SECURITY: Uses environment variables from .env file only.
 * NO HARDCODED CREDENTIALS ALLOWED!
 */

const admin = require('firebase-admin');
const dotenv = require('dotenv');
const { v4: uuidv4 } = require('uuid');

// Load environment variables
dotenv.config();

// Initialize Firebase Admin using environment variables
let firebaseConfig;

// Try different authentication methods
if (process.env.FIREBASE_SERVICE_ACCOUNT_KEY) {
  // Method 1: Service account key from environment variable (JSON string)
  try {
    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_KEY);
    firebaseConfig = {
      credential: admin.credential.cert(serviceAccount),
      databaseURL: process.env.FIREBASE_DATABASE_URL
    };
    console.log('🔑 Using service account from environment variable');
  } catch (error) {
    console.error('❌ Invalid service account JSON in environment variable');
    process.exit(1);
  }
} else {
  // Method 2: Try to load from firebase-admin-key.json file (same as Python scripts)
  try {
    const serviceAccount = require('./firebase-admin-key.json');
    firebaseConfig = {
      credential: admin.credential.cert(serviceAccount),
      databaseURL: process.env.FIREBASE_DATABASE_URL
    };
    console.log('🔑 Using service account from firebase-admin-key.json');
  } catch (error) {
    // Method 3: Fall back to default credentials (gcloud auth)
    firebaseConfig = {
      databaseURL: process.env.FIREBASE_DATABASE_URL
    };
    console.log('🔑 Using default credentials (gcloud auth)');
    console.log('ℹ️  If this fails, create firebase-admin-key.json or authenticate with gcloud');
  }
}

// Initialize Firebase if not already initialized
if (!admin.apps.length) {
  try {
    admin.initializeApp(firebaseConfig);
    console.log('✅ Firebase Admin initialized successfully');
  } catch (error) {
    console.error('❌ Firebase initialization failed:', error.message);
    console.log('\n🔧 Authentication Setup Options:');
    console.log('   1. Download service account key from Firebase Console:');
    console.log('      → Project Settings → Service Accounts → Generate New Private Key');
    console.log('      → Save as firebase-admin-key.json in project root');
    console.log('   2. OR run: gcloud auth application-default login');
    console.log('   3. OR set FIREBASE_SERVICE_ACCOUNT_KEY environment variable');
    process.exit(1);
  }
}

const db = admin.database();

// TurboAir Sales Team - Realistic Mexican sales representatives
const TURBOAIR_SALES_TEAM = [
  {
    id: 'carlos_rodriguez_monterrey',
    email: 'carlos.rodriguez@turboairmexico.com',
    name: 'Carlos Rodriguez',
    title: 'Senior Sales Manager',
    region: 'Norte',
    city: 'Monterrey',
    phone: '+52 81 2345-6789',
    territory: ['Nuevo León', 'Tamaulipas', 'Coahuila'],
    experience_years: 8,
    sales_target_annual: 2500000,
    commission_rate: 0.12
  },
  {
    id: 'maria_gonzalez_cdmx',
    email: 'maria.gonzalez@turboairmexico.com',
    name: 'María González',
    title: 'Sales Representative',
    region: 'Centro',
    city: 'Ciudad de México',
    phone: '+52 55 1234-5678',
    territory: ['CDMX', 'Estado de México', 'Hidalgo'],
    experience_years: 5,
    sales_target_annual: 1800000,
    commission_rate: 0.10
  },
  {
    id: 'juan_martinez_guadalajara',
    email: 'juan.martinez@turboairmexico.com',
    name: 'Juan Martínez',
    title: 'Sales Representative',
    region: 'Occidente',
    city: 'Guadalajara',
    phone: '+52 33 3456-7890',
    territory: ['Jalisco', 'Colima', 'Nayarit'],
    experience_years: 6,
    sales_target_annual: 2000000,
    commission_rate: 0.11
  },
  {
    id: 'ana_lopez_cancun',
    email: 'ana.lopez@turboairmexico.com',
    name: 'Ana López',
    title: 'Sales Representative',
    region: 'Sureste',
    city: 'Cancún',
    phone: '+52 998 987-6543',
    territory: ['Quintana Roo', 'Yucatán', 'Campeche'],
    experience_years: 4,
    sales_target_annual: 1600000,
    commission_rate: 0.10
  },
  {
    id: 'pedro_sanchez_tijuana',
    email: 'pedro.sanchez@turboairmexico.com',
    name: 'Pedro Sánchez',
    title: 'Technical Sales Specialist',
    region: 'Noroeste',
    city: 'Tijuana',
    phone: '+52 664 321-9876',
    territory: ['Baja California', 'Baja California Sur', 'Sonora'],
    experience_years: 7,
    sales_target_annual: 2200000,
    commission_rate: 0.12
  },
  {
    id: 'luis_hernandez_puebla',
    email: 'luis.hernandez@turboairmexico.com',
    name: 'Luis Hernández',
    title: 'Distributor Sales Manager',
    region: 'Centro-Sur',
    city: 'Puebla',
    phone: '+52 222 456-7890',
    territory: ['Puebla', 'Tlaxcala', 'Morelos'],
    experience_years: 9,
    sales_target_annual: 2800000,
    commission_rate: 0.13
  },
  {
    id: 'sofia_ramirez_queretaro',
    email: 'sofia.ramirez@turboairmexico.com',
    name: 'Sofía Ramírez',
    title: 'Sales Representative',
    region: 'Bajío',
    city: 'Querétaro',
    phone: '+52 442 234-5678',
    territory: ['Querétaro', 'Guanajuato', 'San Luis Potosí'],
    experience_years: 3,
    sales_target_annual: 1500000,
    commission_rate: 0.09
  },
  {
    id: 'diego_torres_merida',
    email: 'diego.torres@turboairmexico.com',
    name: 'Diego Torres',
    title: 'Senior Sales Representative',
    region: 'Península',
    city: 'Mérida',
    phone: '+52 999 876-5432',
    territory: ['Yucatán', 'Campeche', 'Tabasco'],
    experience_years: 6,
    sales_target_annual: 1900000,
    commission_rate: 0.11
  },
  {
    id: 'isabella_flores_veracruz',
    email: 'isabella.flores@turboairmexico.com',
    name: 'Isabella Flores',
    title: 'Sales Representative',
    region: 'Golfo',
    city: 'Veracruz',
    phone: '+52 229 345-6789',
    territory: ['Veracruz', 'Tabasco', 'Oaxaca'],
    experience_years: 4,
    sales_target_annual: 1700000,
    commission_rate: 0.10
  },
  {
    id: 'miguel_castro_oaxaca',
    email: 'miguel.castro@turboairmexico.com',
    name: 'Miguel Castro',
    title: 'Regional Manager',
    region: 'Sur',
    city: 'Oaxaca',
    phone: '+52 951 567-8901',
    territory: ['Oaxaca', 'Chiapas', 'Guerrero'],
    experience_years: 10,
    sales_target_annual: 3000000,
    commission_rate: 0.14
  }
];

// Realistic Mexican clients - Hotels, Restaurants, Catering companies
const MEXICAN_CLIENTS_TEMPLATES = [
  // High-end Hotels
  {
    company: 'Hotel Presidente InterContinental {city}',
    contact_name: 'Gerente de Compras',
    business_type: 'Hotel de Lujo',
    employees: 250,
    annual_revenue: 15000000
  },
  {
    company: 'Gran Hotel Ciudad de {city}',
    contact_name: 'Director de Operaciones',
    business_type: 'Hotel Boutique',
    employees: 120,
    annual_revenue: 8000000
  },
  {
    company: 'Hotel Marriott {city}',
    contact_name: 'Jefe de Mantenimiento',
    business_type: 'Hotel Internacional',
    employees: 180,
    annual_revenue: 12000000
  },

  // Restaurants
  {
    company: 'Restaurante Los Arcos {city}',
    contact_name: 'Chef Ejecutivo',
    business_type: 'Restaurante Mariscos',
    employees: 45,
    annual_revenue: 2500000
  },
  {
    company: 'Parrilla Argentina {city}',
    contact_name: 'Gerente General',
    business_type: 'Restaurante Carnes',
    employees: 35,
    annual_revenue: 3200000
  },
  {
    company: 'Cantina La Tradicional {city}',
    contact_name: 'Propietario',
    business_type: 'Restaurante Mexicano',
    employees: 28,
    annual_revenue: 1800000
  },

  // Catering & Food Service
  {
    company: 'Catering Eventos Especiales {city}',
    contact_name: 'Director Comercial',
    business_type: 'Catering Empresarial',
    employees: 65,
    annual_revenue: 4500000
  },
  {
    company: 'Servicios Alimentarios {city}',
    contact_name: 'Jefe de Compras',
    business_type: 'Food Service',
    employees: 85,
    annual_revenue: 6200000
  },

  // Supermarkets & Retail
  {
    company: 'Supermercado La Central {city}',
    contact_name: 'Gerente de Refrigeración',
    business_type: 'Supermercado',
    employees: 150,
    annual_revenue: 25000000
  },
  {
    company: 'Distribuidora de Alimentos {city}',
    contact_name: 'Director de Logística',
    business_type: 'Distribución',
    employees: 95,
    annual_revenue: 18000000
  }
];

// Premium TurboAir products with Mexican pricing (MXN)
const TURBOAIR_PRODUCTS = [
  // Refrigeration Units
  { sku: 'TSR-23SD-N6', name: 'Super Deluxe Refrigerador 1 Puerta', price: 65000, category: 'Refrigeración', line: 'Super Deluxe' },
  { sku: 'TSR-49SD-N6', name: 'Super Deluxe Refrigerador 2 Puertas', price: 85000, category: 'Refrigeración', line: 'Super Deluxe' },
  { sku: 'TSR-72SD-N6', name: 'Super Deluxe Refrigerador 3 Puertas', price: 110000, category: 'Refrigeración', line: 'Super Deluxe' },
  { sku: 'M3R24-1-N', name: 'M3 Series Refrigerador 1 Puerta', price: 55000, category: 'Refrigeración', line: 'M3 Series' },
  { sku: 'M3R48-2-N', name: 'M3 Series Refrigerador 2 Puertas', price: 72000, category: 'Refrigeración', line: 'M3 Series' },
  { sku: 'PRO-26R-N', name: 'PRO Series Refrigerador Compacto', price: 58000, category: 'Refrigeración', line: 'PRO Series' },
  { sku: 'PRO-50R-N', name: 'PRO Series Refrigerador Grande', price: 78000, category: 'Refrigeración', line: 'PRO Series' },

  // Freezers
  { sku: 'TSF-23SD-N', name: 'Super Deluxe Congelador 1 Puerta', price: 68000, category: 'Congeladores', line: 'Super Deluxe' },
  { sku: 'TSF-49SD-N', name: 'Super Deluxe Congelador 2 Puertas', price: 92000, category: 'Congeladores', line: 'Super Deluxe' },
  { sku: 'M3F24-1-N', name: 'M3 Congelador 1 Puerta', price: 62000, category: 'Congeladores', line: 'M3 Series' },
  { sku: 'M3F48-2-N', name: 'M3 Congelador 2 Puertas', price: 85000, category: 'Congeladores', line: 'M3 Series' },

  // Prep Tables
  { sku: 'PST-28-N', name: 'Mesa de Preparación 28"', price: 45000, category: 'Mesas Prep', line: 'Standard' },
  { sku: 'PST-48-N', name: 'Mesa de Preparación 48"', price: 65000, category: 'Mesas Prep', line: 'Standard' },
  { sku: 'PST-60-N', name: 'Mesa de Preparación 60"', price: 78000, category: 'Mesas Prep', line: 'Standard' },
  { sku: 'TST-48SD-12-N-CL', name: 'Mesa Sandwich/Ensalada 48"', price: 72000, category: 'Mesas Prep', line: 'Super Deluxe' },
  { sku: 'TST-60SD-18-N-CL', name: 'Mesa Sandwich/Ensalada 60"', price: 88000, category: 'Mesas Prep', line: 'Super Deluxe' },

  // Display Cases
  { sku: 'TOM-40SB-N', name: 'Vitrina Exhibidora 40"', price: 85000, category: 'Vitrinas', line: 'Open Merchandiser' },
  { sku: 'TOM-50SB-N', name: 'Vitrina Exhibidora 50"', price: 98000, category: 'Vitrinas', line: 'Open Merchandiser' },
  { sku: 'TBP48-46NN-W', name: 'Vitrina Pastelería 48"', price: 115000, category: 'Vitrinas', line: 'Bakery Display' },

  // Spare Parts (commonly ordered)
  { sku: 'SP-MOTOR-001', name: 'Motor Ventilador Evaporador', price: 3500, category: 'Refacciones', line: 'Spare Parts' },
  { sku: 'SP-COMPR-002', name: 'Compresor R404A 1/2 HP', price: 12000, category: 'Refacciones', line: 'Spare Parts' },
  { sku: 'SP-THERM-003', name: 'Termostato Digital', price: 2800, category: 'Refacciones', line: 'Spare Parts' },
  { sku: 'SP-GASKET-004', name: 'Empaque Puerta Universal', price: 1200, category: 'Refacciones', line: 'Spare Parts' },
  { sku: 'SP-RELAY-005', name: 'Relay Arranque Compresor', price: 850, category: 'Refacciones', line: 'Spare Parts' },
  { sku: 'SP-SENSOR-006', name: 'Sensor Temperatura', price: 1500, category: 'Refacciones', line: 'Spare Parts' }
];

// Helper functions
function getRandomDate(daysBack = 90) {
  const now = new Date();
  const pastDate = new Date(now.getTime() - (daysBack * 24 * 60 * 60 * 1000));
  const randomTime = pastDate.getTime() + Math.random() * (now.getTime() - pastDate.getTime());
  return new Date(randomTime);
}

function generateRandomPhone() {
  const areaCodes = ['55', '33', '81', '222', '442', '999', '998', '664', '229', '951'];
  const areaCode = areaCodes[Math.floor(Math.random() * areaCodes.length)];
  const number = Math.floor(Math.random() * 9000000) + 1000000;
  return `+52 ${areaCode} ${String(number).substr(0, 3)}-${String(number).substr(3, 4)}`;
}

function generateMexicanAddress(city, state) {
  const streets = [
    'Av. Juárez', 'Blvd. Miguel Hidalgo', 'Calle Morelos', 'Av. Revolución',
    'Blvd. Venustiano Carranza', 'Calle Benito Juárez', 'Av. Independencia',
    'Blvd. Lázaro Cárdenas', 'Calle Francisco I. Madero', 'Av. 16 de Septiembre'
  ];
  const colonies = [
    'Centro', 'Del Valle', 'Roma Norte', 'Polanco', 'Santa Fe', 'Zona Rosa',
    'Industrial', 'Americana', 'Chapultepec', 'Doctores'
  ];

  const street = streets[Math.floor(Math.random() * streets.length)];
  const number = Math.floor(Math.random() * 9999) + 1;
  const colony = colonies[Math.floor(Math.random() * colonies.length)];
  const cp = String(Math.floor(Math.random() * 90000) + 10000);

  return `${street} ${number}, Col. ${colony}, ${city}, ${state}, C.P. ${cp}`;
}

function generateQuoteNumber() {
  const year = new Date().getFullYear();
  const month = String(new Date().getMonth() + 1).padStart(2, '0');
  const random = Math.floor(Math.random() * 9999) + 1000;
  return `TAQ-${year}${month}-${random}`;
}

function createClientForUser(user, templateIndex) {
  const template = MEXICAN_CLIENTS_TEMPLATES[templateIndex % MEXICAN_CLIENTS_TEMPLATES.length];
  const contactNames = [
    'Carlos Mendoza', 'Ana García', 'Roberto Silva', 'María Fernández',
    'José López', 'Carmen Torres', 'Francisco Morales', 'Lucia Hernández',
    'Miguel Ruiz', 'Esperanza Jiménez', 'Fernando Castro', 'Gloria Vargas'
  ];

  const company = template.company.replace('{city}', user.city);
  const contactName = contactNames[Math.floor(Math.random() * contactNames.length)];
  const email = `${contactName.toLowerCase().replace(' ', '.')}@${company.toLowerCase().replace(/\s+/g, '').replace(/[^a-z0-9]/g, '')}.com.mx`;

  return {
    company: company,
    contact_name: contactName,
    email: email,
    phone: generateRandomPhone(),
    address: generateMexicanAddress(user.city, user.territory[0]),
    city: user.city,
    state: user.territory[0],
    country: 'México',
    business_type: template.business_type,
    employees: template.employees + Math.floor(Math.random() * 50) - 25,
    annual_revenue: template.annual_revenue,
    created_at: getRandomDate(60).toISOString(),
    updated_at: new Date().toISOString(),
    status: 'active',
    assigned_sales_rep: user.id,
    notes: `Cliente asignado a ${user.name} - ${user.title}`,
    tax_id: `RFC${Math.random().toString(36).substr(2, 10).toUpperCase()}`,
    payment_terms: ['NET15', 'NET30', 'NET45'][Math.floor(Math.random() * 3)],
    credit_limit: Math.floor(Math.random() * 500000) + 100000,
    last_order_date: getRandomDate(30).toISOString()
  };
}

function createQuoteItems(isSparePartsOrder = false) {
  let products;
  let itemCount;

  if (isSparePartsOrder) {
    // Spare parts orders: 3-8 different parts
    products = TURBOAIR_PRODUCTS.filter(p => p.category === 'Refacciones');
    itemCount = Math.floor(Math.random() * 6) + 3;
  } else {
    // Equipment orders: 1-4 main units
    products = TURBOAIR_PRODUCTS.filter(p => p.category !== 'Refacciones');
    itemCount = Math.floor(Math.random() * 4) + 1;
  }

  const selectedProducts = [];
  for (let i = 0; i < itemCount; i++) {
    const product = products[Math.floor(Math.random() * products.length)];

    // Avoid duplicates
    if (!selectedProducts.find(p => p.sku === product.sku)) {
      const quantity = isSparePartsOrder ?
        Math.floor(Math.random() * 10) + 1 : // 1-10 spare parts
        Math.floor(Math.random() * 3) + 1;   // 1-3 equipment units

      selectedProducts.push({
        product_id: product.sku,
        sku: product.sku,
        name: product.name,
        price: product.price,
        quantity: quantity,
        total: product.price * quantity,
        category: product.category,
        line: product.line
      });
    }
  }

  return selectedProducts;
}

function createQuote(user, client, status = null, isSparePartsOrder = false) {
  const createdDate = getRandomDate(90);
  const items = createQuoteItems(isSparePartsOrder);

  const subtotal = items.reduce((sum, item) => sum + item.total, 0);
  const taxRate = 0.16; // 16% IVA in Mexico
  const tax = subtotal * taxRate;

  // Shipping calculation for Mexico
  const shipping = subtotal >= 50000 ? 0 : 2500; // Free shipping over $50K MXN

  const total = subtotal + tax + shipping;

  // Quote status
  const statuses = ['draft', 'sent', 'viewed', 'accepted', 'pending', 'approved', 'closed_won', 'closed_lost'];
  const quoteStatus = status || statuses[Math.floor(Math.random() * statuses.length)];

  // Mexican-specific notes
  const mexicanNotes = [
    'Incluye instalación y puesta en marcha',
    'Cliente solicita facturación a fin de mes',
    'Condiciones NET 30 días aprobadas',
    'Pedido urgente - requiere entrega express',
    'Descuento por volumen aplicado - 5% sobre total',
    'Cliente retira en almacén Ciudad de México',
    'Garantía extendida incluida para todos los equipos',
    'Coordinar entrega con Jefe de Mantenimiento',
    'Cliente exento de IVA - constancia en archivo',
    'Cliente preferencial - procesamiento prioritario',
    'Instalación incluye capacitación del personal',
    'Pedido recurrente - cliente de 5+ años'
  ];

  return {
    quote_number: generateQuoteNumber(),
    user_id: user.id,
    client: client,
    items: items,
    subtotal: Math.round(subtotal * 100) / 100,
    tax_rate: taxRate,
    tax: Math.round(tax * 100) / 100,
    shipping: shipping,
    total: Math.round(total * 100) / 100,
    status: quoteStatus,
    created_at: createdDate.toISOString(),
    updated_at: new Date().toISOString(),
    expires_at: new Date(createdDate.getTime() + (30 * 24 * 60 * 60 * 1000)).toISOString(),
    notes: mexicanNotes[Math.floor(Math.random() * mexicanNotes.length)],
    terms: 'Condiciones: IVA incluido. Precios válidos por 30 días. LAB origen.',
    currency: 'MXN',
    payment_terms: client.payment_terms,
    sales_rep: user.name,
    region: user.region,
    is_spare_parts_order: isSparePartsOrder,
    delivery_method: shipping === 0 ? 'free_shipping' : 'standard',
    estimated_delivery: new Date(Date.now() + (7 * 24 * 60 * 60 * 1000)).toISOString()
  };
}

function createProject(user, client, quote) {
  const projectTypes = [
    'Renovación Cocina Completa',
    'Instalación Sistema Refrigeración',
    'Apertura Nueva Sucursal',
    'Actualización Equipos',
    'Expansión Área Food Service',
    'Remplazo Equipos Legacy',
    'Instalación Sistema Walk-in',
    'Proyecto Nuevo Hotel',
    'Modernización Restaurante',
    'Sistema Refrigeración Central'
  ];

  const projectStatuses = ['planning', 'in_progress', 'installation', 'completed', 'on_hold'];

  return {
    id: uuidv4(),
    name: projectTypes[Math.floor(Math.random() * projectTypes.length)],
    client_id: client.company.toLowerCase().replace(/\s+/g, '_').replace(/[^a-z0-9_]/g, ''),
    client_name: client.company,
    user_id: user.id,
    sales_rep: user.name,
    related_quote_id: quote.quote_number,
    status: projectStatuses[Math.floor(Math.random() * projectStatuses.length)],
    start_date: getRandomDate(60).toISOString(),
    estimated_completion: new Date(Date.now() + (45 * 24 * 60 * 60 * 1000)).toISOString(),
    budget: quote.total,
    description: `Proyecto de ${quote.items.length} equipos TurboAir para ${client.business_type}`,
    notes: `Instalación programada para ${client.city}, ${client.state}. Incluye capacitación y puesta en marcha.`,
    created_at: getRandomDate(45).toISOString(),
    updated_at: new Date().toISOString()
  };
}

async function populateUserData(user) {
  console.log(`\n🏗️  Processing sales rep: ${user.name} (${user.city})`);

  try {
    // Create 3-5 clients for this user
    const clientCount = Math.floor(Math.random() * 3) + 3; // 3-5 clients
    const clients = [];

    for (let i = 0; i < clientCount; i++) {
      const client = createClientForUser(user, i);
      clients.push(client);

      // Save client to Firebase
      const clientRef = db.ref(`clients/${user.id}`);
      await clientRef.push(client);
      console.log(`  ✅ Created client: ${client.company}`);
    }

    // Create quotes for each client
    const quotes = [];
    const projects = [];

    for (const client of clients) {
      // 2-3 equipment quotes per client
      const equipmentQuoteCount = Math.floor(Math.random() * 2) + 2;

      for (let i = 0; i < equipmentQuoteCount; i++) {
        // Mix of statuses, with more closed/won for realistic data
        const statuses = ['closed_won', 'sent', 'accepted', 'pending'];
        const status = statuses[Math.floor(Math.random() * statuses.length)];

        const quote = createQuote(user, client, status, false);
        quotes.push(quote);

        // Save quote to Firebase
        const quoteRef = db.ref(`quotes/${user.id}`);
        await quoteRef.push(quote);
        console.log(`  📋 Created equipment quote: ${quote.quote_number} (${quote.status}) - $${quote.total.toLocaleString('es-MX')} MXN`);

        // Create project for bigger orders (>$100K MXN)
        if (quote.total > 100000 && (status === 'accepted' || status === 'closed_won')) {
          const project = createProject(user, client, quote);
          projects.push(project);

          // Save project to Firebase
          const projectRef = db.ref(`projects/${user.id}`);
          await projectRef.push(project);
          console.log(`  🏗️  Created project: ${project.name}`);
        }
      }

      // 1-2 spare parts orders per client (smaller, frequent orders)
      const sparePartsCount = Math.floor(Math.random() * 2) + 1;

      for (let i = 0; i < sparePartsCount; i++) {
        const sparePartsQuote = createQuote(user, client, 'closed_won', true);
        quotes.push(sparePartsQuote);

        // Save spare parts quote
        const quoteRef = db.ref(`quotes/${user.id}`);
        await quoteRef.push(sparePartsQuote);
        console.log(`  🔧 Created spare parts order: ${sparePartsQuote.quote_number} - $${sparePartsQuote.total.toLocaleString('es-MX')} MXN`);
      }
    }

    // Create user profile with sales metrics
    const totalSales = quotes
      .filter(q => q.status === 'closed_won')
      .reduce((sum, q) => sum + q.total, 0);

    const userProfile = {
      ...user,
      total_clients: clients.length,
      total_quotes: quotes.length,
      total_projects: projects.length,
      total_sales_ytd: Math.round(totalSales),
      target_achievement: Math.round((totalSales / user.sales_target_annual) * 100),
      last_activity: new Date().toISOString(),
      created_at: getRandomDate(365).toISOString(),
      updated_at: new Date().toISOString()
    };

    // Save user profile
    const userRef = db.ref(`users/${user.id}`);
    await userRef.set(userProfile);

    console.log(`  💰 Sales YTD: $${totalSales.toLocaleString('es-MX')} MXN (${userProfile.target_achievement}% of target)`);
    console.log(`  📊 Summary: ${clients.length} clients, ${quotes.length} quotes, ${projects.length} projects`);

    return {
      user: userProfile,
      clients: clients.length,
      quotes: quotes.length,
      projects: projects.length,
      sales: totalSales
    };

  } catch (error) {
    console.error(`❌ Error processing ${user.name}:`, error.message);
    throw error;
  }
}

async function populateTurboAirData() {
  console.log('🚀 Starting TurboAir Sales Data Population');
  console.log('=============================================');
  console.log(`📊 Will create data for ${TURBOAIR_SALES_TEAM.length} sales representatives`);
  console.log(`🏢 Across ${new Set(TURBOAIR_SALES_TEAM.map(u => u.region)).size} regions in Mexico`);
  console.log(`💼 Using ${MEXICAN_CLIENTS_TEMPLATES.length} client templates`);
  console.log(`📦 With ${TURBOAIR_PRODUCTS.length} TurboAir products\n`);

  const summary = {
    users: 0,
    totalClients: 0,
    totalQuotes: 0,
    totalProjects: 0,
    totalSales: 0
  };

  try {
    // Process each sales rep
    for (const user of TURBOAIR_SALES_TEAM) {
      const result = await populateUserData(user);

      summary.users++;
      summary.totalClients += result.clients;
      summary.totalQuotes += result.quotes;
      summary.totalProjects += result.projects;
      summary.totalSales += result.sales;

      // Small delay to avoid overwhelming Firebase
      await new Promise(resolve => setTimeout(resolve, 1000));
    }

    // Save population summary
    const populationSummary = {
      populated_at: new Date().toISOString(),
      script_version: '1.0.0',
      users_created: summary.users,
      clients_created: summary.totalClients,
      quotes_created: summary.totalQuotes,
      projects_created: summary.totalProjects,
      total_sales_generated: summary.totalSales,
      currency: 'MXN',
      regions_covered: [...new Set(TURBOAIR_SALES_TEAM.map(u => u.region))],
      average_sales_per_rep: Math.round(summary.totalSales / summary.users)
    };

    await db.ref('population_summary').set(populationSummary);

    console.log('\n🎉 TurboAir Data Population COMPLETED!');
    console.log('=====================================');
    console.log(`👥 Sales Reps: ${summary.users}`);
    console.log(`🏢 Clients: ${summary.totalClients}`);
    console.log(`📋 Quotes: ${summary.totalQuotes}`);
    console.log(`🏗️  Projects: ${summary.totalProjects}`);
    console.log(`💰 Total Sales: $${summary.totalSales.toLocaleString('es-MX')} MXN`);
    console.log(`📊 Avg/Rep: $${Math.round(summary.totalSales / summary.users).toLocaleString('es-MX')} MXN`);
    console.log('\n✅ All data successfully saved to Firebase!');
    console.log('🌐 Data is now available in the TurboAir Quotes app');

  } catch (error) {
    console.error('\n❌ Population failed:', error.message);
    console.log('\n🔧 Troubleshooting tips:');
    console.log('1. Check your Firebase credentials');
    console.log('2. Ensure you have write permissions to the database');
    console.log('3. Verify your internet connection');
    console.log('4. Run: gcloud auth application-default login');
    process.exit(1);
  } finally {
    process.exit(0);
  }
}

// Main execution
if (require.main === module) {
  console.log('🔐 Checking Firebase authentication...');

  // Validate environment variables
  if (!process.env.FIREBASE_DATABASE_URL) {
    console.error('❌ FIREBASE_DATABASE_URL not found in environment variables');
    console.log('💡 Make sure your .env file contains the Firebase configuration');
    process.exit(1);
  }

  console.log('✅ Environment variables loaded');
  console.log(`🎯 Target database: ${process.env.FIREBASE_DATABASE_URL}`);

  // Start population
  populateTurboAirData();
}

module.exports = {
  populateTurboAirData,
  TURBOAIR_SALES_TEAM,
  MEXICAN_CLIENTS_TEMPLATES,
  TURBOAIR_PRODUCTS
};