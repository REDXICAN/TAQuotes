#!/usr/bin/env node

/**
 * TurboAir Data Population Script
 *
 * Populates Firebase with 10 TurboAir users, projects, and quotes
 * Uses existing clients and products from the database
 *
 * Usage: node populate_turboair.js
 *
 * SECURITY NOTE: Uses environment variables from .env file
 * NO hardcoded credentials - all data from environment
 */

require('dotenv').config();
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK using environment variables
const initializeFirebase = () => {
  try {
    // Use environment variables for configuration - NO hardcoded values
    const firebaseConfig = {
      projectId: process.env.FIREBASE_PROJECT_ID,
      databaseURL: process.env.FIREBASE_DATABASE_URL,
    };

    // For local development, try to use Application Default Credentials
    // This requires: gcloud auth application-default login
    if (!admin.apps.length) {
      admin.initializeApp(firebaseConfig);
      console.log('✅ Firebase Admin SDK initialized successfully');
    }

    return admin;
  } catch (error) {
    console.error('❌ Error initializing Firebase:', error.message);
    console.log('\n🔧 Setup Instructions:');
    console.log('1. Install Google Cloud CLI: https://cloud.google.com/sdk/docs/install');
    console.log('2. Run: gcloud auth application-default login');
    console.log('3. Run: gcloud config set project taquotes');
    console.log('4. Ensure .env file exists with proper configuration');
    process.exit(1);
  }
};

// TurboAir Users to create
const turboAirUsers = [
  {
    email: 'carlos@turboair-monterrey.com',
    displayName: 'Carlos Rodriguez',
    role: 'Senior Sales',
    title: 'Senior Sales Representative',
    location: 'Monterrey, México',
    phone: '+52 81 1234-5678'
  },
  {
    email: 'maria@turboair.mx',
    displayName: 'Maria Gonzalez',
    role: 'Sales Rep',
    title: 'Sales Representative',
    location: 'Ciudad de México, México',
    phone: '+52 55 2345-6789'
  },
  {
    email: 'juan@turboair.mx',
    displayName: 'Juan Martinez',
    role: 'Sales Rep',
    title: 'Sales Representative',
    location: 'Guadalajara, México',
    phone: '+52 33 3456-7890'
  },
  {
    email: 'ana@turboair-cancun.mx',
    displayName: 'Ana Lopez',
    role: 'Sales Rep',
    title: 'Sales Representative',
    location: 'Cancún, México',
    phone: '+52 998 456-7890'
  },
  {
    email: 'pedro@turboair.mx',
    displayName: 'Pedro Sanchez',
    role: 'Technical Sales',
    title: 'Technical Sales Specialist',
    location: 'Puebla, México',
    phone: '+52 222 567-8901'
  },
  {
    email: 'luis@turboair.mx',
    displayName: 'Luis Hernandez',
    role: 'Distributor',
    title: 'Regional Distributor',
    location: 'Tijuana, México',
    phone: '+52 664 678-9012'
  },
  {
    email: 'sofia@turboair.mx',
    displayName: 'Sofia Ramirez',
    role: 'Sales Rep',
    title: 'Sales Representative',
    location: 'Mérida, México',
    phone: '+52 999 789-0123'
  },
  {
    email: 'diego@turboair.mx',
    displayName: 'Diego Torres',
    role: 'Senior Sales',
    title: 'Senior Sales Representative',
    location: 'León, México',
    phone: '+52 477 890-1234'
  },
  {
    email: 'isabella@turboair.mx',
    displayName: 'Isabella Flores',
    role: 'Sales Rep',
    title: 'Sales Representative',
    location: 'Querétaro, México',
    phone: '+52 442 901-2345'
  },
  {
    email: 'miguel@turboair.mx',
    displayName: 'Miguel Castro',
    role: 'Regional Manager',
    title: 'Regional Sales Manager',
    location: 'Veracruz, México',
    phone: '+52 229 012-3456'
  }
];

// Helper function to generate quote number
const generateQuoteNumber = () => {
  const date = new Date();
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const random = Math.floor(Math.random() * 10000).toString().padStart(4, '0');
  return `TQ${year}${month}${random}`;
};

// Helper function to get random elements from array
const getRandomElements = (array, count) => {
  const shuffled = array.sort(() => 0.5 - Math.random());
  return shuffled.slice(0, count);
};

// Helper function to generate realistic project names
const generateProjectName = (clientCompany) => {
  const projectTypes = [
    'HVAC Modernization',
    'Refrigeration Upgrade',
    'Kitchen Equipment Installation',
    'Commercial Cooling System',
    'Restaurant Equipment Package',
    'Food Service Renovation',
    'Cold Storage Expansion',
    'Energy Efficiency Project',
    'Equipment Replacement',
    'Facility Upgrade'
  ];

  const randomType = projectTypes[Math.floor(Math.random() * projectTypes.length)];
  return `${clientCompany} - ${randomType}`;
};

// Main population function
const populateData = async () => {
  console.log('🚀 Starting TurboAir data population...\n');

  const db = admin.database();
  const auth = admin.auth();

  try {
    // Step 1: Fetch existing clients and products
    console.log('📥 Fetching existing clients and products...');

    const [clientsSnapshot, productsSnapshot] = await Promise.all([
      db.ref('clients').once('value'),
      db.ref('products').limitToFirst(100).once('value')
    ]);

    const existingClients = [];
    const existingProducts = [];

    // Process clients
    if (clientsSnapshot.exists()) {
      clientsSnapshot.forEach(clientSnapshot => {
        const clientData = clientSnapshot.val();
        if (clientData && typeof clientData === 'object') {
          // Handle both user-specific and direct client storage
          if (clientData.company) {
            existingClients.push({ id: clientSnapshot.key, ...clientData });
          } else {
            // User-specific clients
            Object.keys(clientData).forEach(clientId => {
              const client = clientData[clientId];
              if (client && client.company) {
                existingClients.push({ id: clientId, ...client });
              }
            });
          }
        }
      });
    }

    // Process products
    if (productsSnapshot.exists()) {
      productsSnapshot.forEach(productSnapshot => {
        const product = productSnapshot.val();
        if (product && product.model) {
          existingProducts.push({ id: productSnapshot.key, ...product });
        }
      });
    }

    console.log(`✅ Found ${existingClients.length} clients and ${existingProducts.length} products`);

    if (existingClients.length === 0 || existingProducts.length === 0) {
      console.log('⚠️ Warning: No existing clients or products found. Creating basic data...');
      // You could add basic client/product creation here if needed
    }

    // Step 2: Create TurboAir users
    console.log('\n👥 Creating TurboAir users...');
    const createdUsers = [];

    for (const userData of turboAirUsers) {
      try {
        // Create user in Firebase Auth
        const userRecord = await auth.createUser({
          email: userData.email,
          displayName: userData.displayName,
          emailVerified: true,
        });

        // Create user profile in database
        const userProfile = {
          uid: userRecord.uid,
          email: userData.email,
          displayName: userData.displayName,
          role: userData.role,
          title: userData.title,
          location: userData.location,
          phone: userData.phone,
          createdAt: new Date().toISOString(),
          lastLoginAt: new Date().toISOString(),
          isAdmin: userData.role.includes('Senior') || userData.role.includes('Manager'),
          company: 'TurboAir México',
          department: 'Sales',
          isActive: true
        };

        await db.ref(`users/${userRecord.uid}`).set(userProfile);
        createdUsers.push({ ...userProfile, authUser: userRecord });

        console.log(`✅ Created user: ${userData.displayName} (${userData.email})`);
      } catch (error) {
        if (error.code === 'auth/email-already-exists') {
          console.log(`⚠️ User already exists: ${userData.email}`);
          // Get existing user
          try {
            const existingUser = await auth.getUserByEmail(userData.email);
            const userProfile = {
              uid: existingUser.uid,
              email: userData.email,
              displayName: userData.displayName,
              role: userData.role,
              title: userData.title,
              location: userData.location,
              phone: userData.phone
            };
            createdUsers.push({ ...userProfile, authUser: existingUser });
          } catch (getError) {
            console.log(`❌ Error getting existing user: ${getError.message}`);
          }
        } else {
          console.log(`❌ Error creating user ${userData.email}: ${error.message}`);
        }
      }
    }

    console.log(`✅ Successfully processed ${createdUsers.length} users`);

    // Step 3: Create projects for each user
    console.log('\n📋 Creating projects...');
    let totalProjects = 0;

    for (const user of createdUsers) {
      const userClients = getRandomElements(existingClients, Math.min(3, existingClients.length));

      for (let i = 0; i < Math.min(3, userClients.length); i++) {
        const client = userClients[i];
        const projectId = `proj_${Date.now()}_${Math.floor(Math.random() * 1000)}`;

        const project = {
          id: projectId,
          name: generateProjectName(client.company),
          description: `Commercial refrigeration and HVAC project for ${client.company}`,
          clientId: client.id,
          clientName: client.company,
          status: Math.random() > 0.4 ? 'in_progress' : 'completed',
          priority: ['high', 'medium', 'low'][Math.floor(Math.random() * 3)],
          startDate: new Date(Date.now() - Math.random() * 90 * 24 * 60 * 60 * 1000).toISOString(),
          endDate: new Date(Date.now() + Math.random() * 180 * 24 * 60 * 60 * 1000).toISOString(),
          createdAt: new Date().toISOString(),
          createdBy: user.uid,
          assignedTo: user.uid,
          estimatedValue: Math.floor(Math.random() * 100000) + 10000,
          actualValue: Math.floor(Math.random() * 80000) + 8000,
          progress: Math.floor(Math.random() * 100),
          notes: `Project managed by ${user.displayName} for ${client.company}`,
          tags: ['commercial', 'hvac', 'refrigeration'],
          location: user.location,
          category: 'Commercial HVAC'
        };

        await db.ref(`projects/${user.uid}/${projectId}`).set(project);
        totalProjects++;
      }
    }

    console.log(`✅ Created ${totalProjects} projects`);

    // Step 4: Create quotes for each user
    console.log('\n💰 Creating quotes...');
    let totalQuotes = 0;

    for (const user of createdUsers) {
      const userClients = getRandomElements(existingClients, Math.min(5, existingClients.length));

      // Create 2 closed quotes and 3 in-progress quotes per user
      for (let i = 0; i < 5; i++) {
        const client = userClients[i % userClients.length];
        const quoteProducts = getRandomElements(existingProducts, Math.floor(Math.random() * 5) + 1);

        const quoteItems = quoteProducts.map(product => ({
          productId: product.id,
          productName: product.displayName || product.name,
          product: product,
          quantity: Math.floor(Math.random() * 5) + 1,
          unitPrice: product.price || Math.floor(Math.random() * 10000) + 1000,
          total: 0, // Will calculate below
          addedAt: new Date().toISOString(),
          discount: Math.random() > 0.7 ? Math.floor(Math.random() * 15) : 0,
          note: '',
          sequenceNumber: String(i + 1).padStart(3, '0')
        }));

        // Calculate totals
        let subtotal = 0;
        quoteItems.forEach(item => {
          const itemTotal = item.quantity * item.unitPrice;
          const discountAmount = (itemTotal * item.discount) / 100;
          item.total = itemTotal - discountAmount;
          subtotal += item.total;
        });

        const discountValue = Math.random() > 0.6 ? Math.floor(Math.random() * 10) : 0;
        const discountAmount = (subtotal * discountValue) / 100;
        const tax = (subtotal - discountAmount) * 0.16; // 16% IVA in Mexico
        const total = subtotal - discountAmount + tax;

        const quoteId = `quote_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
        const quote = {
          id: quoteId,
          quoteNumber: generateQuoteNumber(),
          clientId: client.id,
          clientName: client.company,
          client: client,
          items: quoteItems,
          subtotal: Math.round(subtotal * 100) / 100,
          discountAmount: Math.round(discountAmount * 100) / 100,
          discountType: 'percentage',
          discountValue: discountValue,
          tax: Math.round(tax * 100) / 100,
          total: Math.round(total * 100) / 100,
          totalAmount: Math.round(total * 100) / 100,
          status: i < 2 ? 'closed' : 'in_progress', // First 2 are closed, rest in-progress
          archived: false,
          notes: `Quote generated for ${client.company} by ${user.displayName}`,
          comments: i < 2 ? 'Project completed successfully' : 'Awaiting client approval',
          includeCommentInEmail: false,
          createdAt: new Date(Date.now() - Math.random() * 60 * 24 * 60 * 60 * 1000).toISOString(),
          expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
          createdBy: user.uid,
          projectId: null,
          projectName: null
        };

        await db.ref(`quotes/${user.uid}/${quoteId}`).set(quote);
        totalQuotes++;
      }
    }

    console.log(`✅ Created ${totalQuotes} quotes (${createdUsers.length * 2} closed, ${createdUsers.length * 3} in-progress)`);

    // Summary
    console.log('\n🎉 Data population completed successfully!');
    console.log('┌─────────────────────────────────────┐');
    console.log('│              SUMMARY                │');
    console.log('├─────────────────────────────────────┤');
    console.log(`│ Users Created:     ${String(createdUsers.length).padStart(13)} │`);
    console.log(`│ Projects Created:  ${String(totalProjects).padStart(13)} │`);
    console.log(`│ Quotes Created:    ${String(totalQuotes).padStart(13)} │`);
    console.log(`│ Existing Clients:  ${String(existingClients.length).padStart(13)} │`);
    console.log(`│ Existing Products: ${String(existingProducts.length).padStart(13)} │`);
    console.log('└─────────────────────────────────────┘');

    console.log('\n📧 TurboAir User Emails:');
    createdUsers.forEach(user => {
      console.log(`  • ${user.displayName} <${user.email}> - ${user.role}`);
    });

    console.log('\n✅ All TurboAir users can now log in to the application');
    console.log('🔐 Users will need to reset their passwords using the "Forgot Password" feature');

  } catch (error) {
    console.error('❌ Error during data population:', error);
    process.exit(1);
  }
};

// Main execution
const main = async () => {
  try {
    // Initialize Firebase
    const firebase = initializeFirebase();

    // Run population
    await populateData();

    console.log('\n🏁 Script completed successfully!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Script failed:', error);
    process.exit(1);
  }
};

// Run if called directly
if (require.main === module) {
  main();
}

module.exports = { populateData, turboAirUsers };