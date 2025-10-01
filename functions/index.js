// Firebase Cloud Functions for Email Service
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');
const cors = require('cors')({ origin: true });

// Initialize Firebase Admin
admin.initializeApp();

// Helper function to format currency with commas
function formatCurrency(amount) {
  const num = parseFloat(amount) || 0;
  return '$' + num.toFixed(2).replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

// Gmail SMTP configuration
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_SENDER_ADDRESS || 'turboairquotes@gmail.com',
    pass: process.env.EMAIL_APP_PASSWORD || functions.config().email?.app_password
  }
});

// ========== CUSTOM CLAIMS FUNCTIONS FOR SECURITY ==========

// Function to set custom claims for user roles
exports.setUserClaims = functions.https.onCall(async (data, context) => {
  // Check if request is made by an authenticated user
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Request must be authenticated'
    );
  }

  // Check if the requesting user is a super admin
  const callerClaims = context.auth.token;
  if (!callerClaims.superAdmin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only super admins can set user claims'
    );
  }

  const { uid, claims } = data;

  // Validate input
  if (!uid || !claims) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Missing uid or claims'
    );
  }

  // Validate role
  const validRoles = ['admin', 'sales', 'distributor', 'superAdmin'];
  if (claims.role && !validRoles.includes(claims.role)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `Invalid role: ${claims.role}`
    );
  }

  try {
    // Set custom claims
    const customClaims = {};
    
    // Set role-based boolean flags
    if (claims.role === 'superAdmin') {
      customClaims.superAdmin = true;
      customClaims.admin = true;
    } else if (claims.role === 'admin') {
      customClaims.admin = true;
      customClaims.superAdmin = false;
    } else {
      customClaims.admin = false;
      customClaims.superAdmin = false;
    }
    
    customClaims.role = claims.role;

    await admin.auth().setCustomUserClaims(uid, customClaims);

    // Log the action
    await admin.database().ref('audit_logs').push({
      user_id: context.auth.uid,
      action: 'set_custom_claims',
      target_uid: uid,
      claims: customClaims,
      timestamp: admin.database.ServerValue.TIMESTAMP,
    });

    return {
      success: true,
      message: `Custom claims set for user ${uid}`,
    };
  } catch (error) {
    console.error('Error setting custom claims:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to set custom claims'
    );
  }
});

// Function to initialize super admin (run once)
exports.initializeSuperAdmin = functions.https.onRequest(async (req, res) => {
  cors(req, res, async () => {
    // IMPORTANT: Secure this endpoint in production!
    const secretToken = req.headers['x-init-token'];
    const expectedToken = process.env.INIT_TOKEN || functions.config().init?.token || 'TAQUOTES_INIT_2024';
    
    if (secretToken !== expectedToken) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const superAdminEmail = 'andres@turboairmexico.com';

    try {
      // Get user by email
      const user = await admin.auth().getUserByEmail(superAdminEmail);
      
      // Set super admin claims
      await admin.auth().setCustomUserClaims(user.uid, {
        superAdmin: true,
        admin: true,
        role: 'superAdmin',
      });

      // Update user profile in database
      await admin.database().ref(`user_profiles/${user.uid}`).update({
        role: 'superAdmin',
        claims_set: true,
        updated_at: admin.database.ServerValue.TIMESTAMP,
      });

      res.json({
        success: true,
        message: `Super admin claims set for ${superAdminEmail}`,
        uid: user.uid
      });
    } catch (error) {
      console.error('Error initializing super admin:', error);
      res.status(500).json({
        success: false,
        error: error.message,
      });
    }
  });
});

// Function to verify user claims
exports.verifyUserClaims = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Request must be authenticated'
    );
  }

  const uid = data.uid || context.auth.uid;

  try {
    const user = await admin.auth().getUser(uid);
    
    return {
      uid: user.uid,
      email: user.email,
      customClaims: user.customClaims || {},
    };
  } catch (error) {
    throw new functions.https.HttpsError(
      'internal',
      'Failed to verify user claims'
    );
  }
});

// Cloud function to send quote email with attachments
exports.sendQuoteEmail = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    // Only allow POST requests
    if (req.method !== 'POST') {
      return res.status(405).json({ error: 'Method not allowed' });
    }

    try {
      const {
        recipientEmail,
        recipientName,
        quoteNumber,
        totalAmount,
        pdfBase64,
        excelBase64,
        attachPdf = true,
        attachExcel = false,
        products = [] // Array of products with name, sku, quantity, price
      } = req.body;

      // Validate required fields
      if (!recipientEmail || !recipientName || !quoteNumber || !totalAmount) {
        return res.status(400).json({ 
          error: 'Missing required fields',
          required: ['recipientEmail', 'recipientName', 'quoteNumber', 'totalAmount']
        });
      }

      // Prepare email attachments
      const attachments = [];
      
      if (attachPdf && pdfBase64) {
        // PDF attachment added
        attachments.push({
          filename: `Quote_${quoteNumber}.pdf`,
          content: pdfBase64,
          encoding: 'base64',
          contentType: 'application/pdf'
        });
      }
      
      if (attachExcel && excelBase64) {
        // Excel attachment added
        attachments.push({
          filename: `Quote_${quoteNumber}.xlsx`,
          content: excelBase64,
          encoding: 'base64',
          contentType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        });
      }
      
      // Attachments prepared

      // Format products list for text email
      let productsText = '';
      let productsHtml = '';
      
      if (products && products.length > 0) {
        productsText = '\n\nProducts:\n';
        productsHtml = `
          <div class="details">
            <h3>Products</h3>
            <table style="width: 100%; border-collapse: collapse;">
              <thead>
                <tr style="background-color: #f0f0f0;">
                  <th style="padding: 8px; text-align: left; border: 1px solid #ddd; white-space: nowrap;">SKU</th>
                  <th style="padding: 8px; text-align: left; border: 1px solid #ddd;">Product</th>
                  <th style="padding: 8px; text-align: center; border: 1px solid #ddd;">Qty</th>
                  <th style="padding: 8px; text-align: right; border: 1px solid #ddd; white-space: nowrap;">Unit Price</th>
                  <th style="padding: 8px; text-align: right; border: 1px solid #ddd; white-space: nowrap;">Total</th>
                </tr>
              </thead>
              <tbody>`;
        
        products.forEach(product => {
          const unitPrice = parseFloat(product.unitPrice || 0);
          const quantity = parseInt(product.quantity || 1);
          const total = unitPrice * quantity;
          
          productsText += `- ${product.sku || 'N/A'} - ${product.name || 'Unknown'} (Qty: ${quantity}) - ${formatCurrency(unitPrice)} each = ${formatCurrency(total)}\n`;
          
          productsHtml += `
            <tr>
              <td style="padding: 8px; border: 1px solid #ddd; white-space: nowrap;">${product.sku || 'N/A'}</td>
              <td style="padding: 8px; border: 1px solid #ddd;">${product.name || 'Unknown'}</td>
              <td style="padding: 8px; text-align: center; border: 1px solid #ddd;">${quantity}</td>
              <td style="padding: 8px; text-align: right; border: 1px solid #ddd; white-space: nowrap;">${formatCurrency(unitPrice)}</td>
              <td style="padding: 8px; text-align: right; border: 1px solid #ddd; white-space: nowrap;">${formatCurrency(total)}</td>
            </tr>`;
        });
        
        productsHtml += `
              </tbody>
            </table>
          </div>`;
      }

      // Email options
      const mailOptions = {
        from: '"TurboAir Quotes" <turboairquotes@gmail.com>',
        to: recipientEmail,
        subject: `Quote #${quoteNumber} from TurboAir`,
        text: `
Dear ${recipientName},

Please find attached your quote #${quoteNumber}.

Quote Details:
- Quote Number: ${quoteNumber}
- Total Amount: ${formatCurrency(totalAmount)}
- Date: ${new Date().toISOString().split('T')[0]}
${productsText}
Thank you for your business!

Best regards,
TurboAir Quote System
        `,
        html: `
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background-color: #2196F3; color: white; padding: 20px; text-align: center; border-radius: 5px 5px 0 0; }
    .content { padding: 20px; background-color: #f5f5f5; }
    .details { background: white; padding: 15px; margin: 15px 0; border-radius: 5px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    .footer { text-align: center; padding: 10px; color: #666; font-size: 12px; }
    .logo { max-width: 200px; margin-bottom: 10px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>TurboAir Quote System</h1>
      <p style="margin: 0;">Professional Equipment Solutions</p>
    </div>
    <div class="content">
      <h2>Dear ${recipientName},</h2>
      <p>Thank you for your interest in TurboAir products. Please find your quote details below:</p>
      
      <div class="details">
        <h3>Quote Details</h3>
        <p><strong>Quote Number:</strong> ${quoteNumber}</p>
        <p><strong>Total Amount:</strong> ${formatCurrency(totalAmount)}</p>
        <p><strong>Date:</strong> ${new Date().toISOString().split('T')[0]}</p>
      </div>
      
      ${productsHtml}
      
      ${attachments.length > 0 ? `
      <div class="details">
        <h3>Attachments</h3>
        <ul>
          ${attachPdf && pdfBase64 ? '<li>Quote PDF Document</li>' : ''}
          ${attachExcel && excelBase64 ? '<li>Quote Excel Spreadsheet</li>' : ''}
        </ul>
      </div>
      ` : ''}
      
      <p>If you have any questions, please don't hesitate to contact us.</p>
      
      <p>Best regards,<br>
      TurboAir Quote System</p>
    </div>
    <div class="footer">
      <p>© ${new Date().getFullYear()} TurboAir. All rights reserved.</p>
      <p>This is an automated email. Please do not reply directly to this message.</p>
    </div>
  </div>
</body>
</html>
        `,
        attachments: attachments
      };

      // Send email
      const info = await transporter.sendMail(mailOptions);
      
      // Email sent successfully
      
      return res.status(200).json({ 
        success: true, 
        messageId: info.messageId,
        message: 'Email sent successfully'
      });
      
    } catch (error) {
      // Error logged internally by Firebase Functions
      return res.status(500).json({ 
        error: 'Failed to send email',
        details: error.message 
      });
    }
  });
});

// Test function to verify email configuration
exports.testEmail = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const { recipientEmail } = req.body || req.query;

      if (!recipientEmail) {
        return res.status(400).json({ error: 'recipientEmail is required' });
      }

      const mailOptions = {
        from: '"TurboAir Quotes" <turboairquotes@gmail.com>',
        to: recipientEmail,
        subject: 'Test Email from TurboAir Quote System',
        text: 'This is a test email to verify the email configuration.',
        html: `
          <h2>Test Email</h2>
          <p>This is a test email from the TurboAir Quote System.</p>
          <p>If you receive this email, the configuration is working correctly.</p>
          <hr>
          <p><small>Sent from TurboAir Quote System via Firebase Functions</small></p>
        `
      };

      const info = await transporter.sendMail(mailOptions);

      return res.status(200).json({
        success: true,
        messageId: info.messageId,
        message: 'Test email sent successfully'
      });

    } catch (error) {
      // Error logged internally by Firebase Functions
      return res.status(500).json({
        error: 'Failed to send test email',
        details: error.message
      });
    }
  });
});

// ========== ONEDRIVE EXCEL IMPORT FUNCTIONS ==========

const axios = require('axios');
const XLSX = require('xlsx');

// Helper function to download Excel directly from public OneDrive share link
// No authentication needed for publicly shared files
async function downloadExcelFromPublicLink(shareLink) {
  try {
    console.log('Attempting to download from public OneDrive share link...');

    // Convert the share link to a direct download link
    // OneDrive share links can be converted by changing the action parameter
    let downloadLink = shareLink;

    // Method 1: Replace action parameter
    if (shareLink.includes('action=')) {
      downloadLink = shareLink.replace(/action=[^&]+/, 'action=download');
    } else if (shareLink.includes('?')) {
      downloadLink = shareLink + '&action=download';
    } else {
      downloadLink = shareLink + '?action=download';
    }

    console.log('Attempting download from:', downloadLink);

    // Download the file
    const response = await axios.get(downloadLink, {
      responseType: 'arraybuffer',
      maxRedirects: 10,
      timeout: 60000,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      }
    });

    if (!response || !response.data) {
      throw new Error('No data received from OneDrive');
    }

    console.log(`Successfully downloaded ${response.data.byteLength} bytes from OneDrive`);
    return response.data;
  } catch (error) {
    console.error('Failed to download from public link:', error.message);
    throw new Error('Unable to download file. Please ensure the OneDrive link is publicly accessible.');
  }
}

// Helper function to extract file ID from OneDrive share link
function extractFileIdFromShareLink(shareLink) {
  try {
    // OneDrive share links format:
    // https://onedrive.live.com/personal/{user}/_layouts/15/Doc.aspx?sourcedoc={fileId}&action=default
    const match = shareLink.match(/sourcedoc=\{([^}]+)\}/i) || shareLink.match(/resid=([^&]+)/i);
    if (match && match[1]) {
      return match[1];
    }
    throw new Error('Could not extract file ID from share link');
  } catch (error) {
    console.error('Error extracting file ID:', error.message);
    throw error;
  }
}

// This function is no longer needed - using downloadExcelFromPublicLink instead

// Helper function to parse Excel data
function parseExcelData(excelBuffer) {
  try {
    console.log('Parsing Excel data...');

    // Read the Excel file
    const workbook = XLSX.read(excelBuffer, { type: 'buffer' });

    // Get the first sheet (USA-MEX - LOCALES)
    const sheetName = workbook.SheetNames[0];
    const sheet = workbook.Sheets[sheetName];

    console.log(`Reading sheet: ${sheetName}`);

    // Convert to JSON starting from row 3 (headers) and row 4 (data)
    const jsonData = XLSX.utils.sheet_to_json(sheet, {
      header: 1,
      defval: '',
      blankrows: false,
      range: 2 // Start from row 3 (0-indexed, so row 3 = index 2)
    });

    if (jsonData.length < 2) {
      throw new Error('Excel file has no data rows');
    }

    // Get headers (first row after range starts at row 3)
    const headers = jsonData[0];
    console.log('Excel headers found:', headers.filter(h => h).length, 'columns');

    // Convert rows to objects
    const data = [];
    for (let i = 1; i < jsonData.length; i++) {
      const row = jsonData[i];
      const rowObject = {};

      // Map columns to tracking data fields
      // Column mapping based on actual Excel structure:
      // Col 2: FECHA DE ENTRADA
      // Col 3: # DE PEDIDO
      // Col 4: OC
      // Col 5: ESTATUS
      // Col 6: CLIENTE
      // Col 7: VENDEDOR
      // Col 8: DESTINO
      // Col 9: REFERENCIA
      // Col 10: PROVEEDOR/ ORIGEN
      // Col 11: SALES ORDER
      // Col 12: TRANSFER
      // Col 13: SALES INVOICE
      // Col 14: FECHA FACTURA
      // Col 15: ARRIBO A ADUANA
      // Col 16: NUM. DE PEDIMENTO
      // Col 17: REMISIÓN
      // Col 18: FLETERA
      // Col 19: GUIA
      // Col 20: DOCUMENTADO
      // Col 21: ENTREGA CANCÚN
      // Col 22: ENTREGA APROXIMADA
      // Col 23: ENTREGA REAL

      rowObject.fecha_entrada = row[1] || ''; // Column 2
      rowObject.numero_pedido = row[2] || ''; // Column 3
      rowObject.oc = row[3] || ''; // Column 4
      rowObject.estatus = row[4] || ''; // Column 5
      rowObject.cliente = row[5] || ''; // Column 6
      rowObject.vendedor = row[6] || ''; // Column 7
      rowObject.destino = row[7] || ''; // Column 8
      rowObject.referencia = row[8] || ''; // Column 9
      rowObject.proveedor_origen = row[9] || ''; // Column 10
      rowObject.sales_order = row[10] || ''; // Column 11
      rowObject.transfer = row[11] || ''; // Column 12
      rowObject.sales_invoice = row[12] || ''; // Column 13
      rowObject.fecha_factura = row[13] || ''; // Column 14
      rowObject.arribo_aduana = row[14] || ''; // Column 15
      rowObject.num_pedimento = row[15] || ''; // Column 16
      rowObject.remision = row[16] || ''; // Column 17
      rowObject.fletera = row[17] || ''; // Column 18
      rowObject.guia = row[18] || ''; // Column 19
      rowObject.documentado = row[19] || ''; // Column 20
      rowObject.entrega_cancun = row[20] || ''; // Column 21
      rowObject.entrega_aproximada = row[21] || ''; // Column 22
      rowObject.entrega_real = row[22] || ''; // Column 23

      // Only add rows with at least numero_pedido or oc
      if (rowObject.numero_pedido || rowObject.oc) {
        data.push(rowObject);
      }
    }

    console.log(`Parsed ${data.length} tracking records from Excel`);
    return data;
  } catch (error) {
    console.error('Error parsing Excel data:', error.message);
    throw new Error('Failed to parse Excel file');
  }
}

// Helper function to import tracking data to Firebase
async function importTrackingDataToFirebase(trackingData) {
  try {
    console.log('Importing tracking data to Firebase...');

    const db = admin.database();
    const trackingRef = db.ref('tracking');

    // Create a batch update object
    const updates = {};
    const timestamp = admin.database.ServerValue.TIMESTAMP;

    trackingData.forEach((record, index) => {
      // Generate a unique key for each record (use numero_pedido or OC)
      const pedidoNumber = record.numero_pedido || record.oc || `PEDIDO_${Date.now()}_${index}`;
      const sanitizedKey = String(pedidoNumber).replace(/[.#$\[\]\/\s]/g, '_');

      // Structure the data
      updates[sanitizedKey] = {
        ...record,
        imported_at: timestamp,
        last_updated: timestamp
      };
    });

    // Perform batch update
    await trackingRef.update(updates);

    console.log(`Successfully imported ${Object.keys(updates).length} tracking records`);

    // Log the import action
    await db.ref('import_logs').push({
      type: 'onedrive_excel_import',
      records_count: Object.keys(updates).length,
      timestamp: timestamp,
      status: 'success'
    });

    return {
      success: true,
      recordsImported: Object.keys(updates).length
    };
  } catch (error) {
    console.error('Error importing tracking data to Firebase:', error.message);

    // Log the failed import
    await admin.database().ref('import_logs').push({
      type: 'onedrive_excel_import',
      timestamp: admin.database.ServerValue.TIMESTAMP,
      status: 'failed',
      error: error.message
    });

    throw new Error('Failed to import tracking data to Firebase');
  }
}

// Scheduled function to import Excel from OneDrive every 30 minutes
exports.scheduledOneDriveImport = functions.pubsub
  .schedule('every 30 minutes')
  .timeZone('America/Mexico_City')
  .onRun(async (context) => {
    console.log('Starting scheduled OneDrive Excel import...');

    try {
      // Get OneDrive share link from environment variable or use default
      const shareLink = process.env.ONEDRIVE_SHARE_LINK ||
                       functions.config().onedrive?.share_link ||
                       'https://onedrive.live.com/personal/537ba0d7826179ca/_layouts/15/Doc.aspx?sourcedoc=%7B826179ca-a0d7-207b-8053-2e6a00000000%7D&action=default&redeem=aHR0cHM6Ly8xZHJ2Lm1zL3gvcyFBc3A1WVlMWG9IdFRnZFF1MU5JTGtIRVRicEJoWWc_ZT1MYVBScm4&slrid=9a30cba1-60dd-a000-529b-02f45f3fb372&originalPath=aHR0cHM6Ly8xZHJ2Lm1zL3gvYy81MzdiYTBkNzgyNjE3OWNhL1FjcDVZWUxYb0hzZ2dGTXVhZ0FBQUFBQTFOSUxrSEVUYnBCaFlnP3J0aW1lPVNaUTFxaEVCM2tn&CID=94d7ba4c-9289-4c7b-acf6-67a89815c258&_SRM=0:G:45';

      console.log('Using share link:', shareLink.substring(0, 100) + '...');

      // Download Excel file directly from public OneDrive link
      const excelBuffer = await downloadExcelFromPublicLink(shareLink);

      // Parse Excel data
      const trackingData = parseExcelData(excelBuffer);

      // Import to Firebase
      const result = await importTrackingDataToFirebase(trackingData);

      console.log('Scheduled import completed successfully:', result);
      return result;
    } catch (error) {
      console.error('Scheduled import failed:', error.message);

      // Send alert email to admin
      try {
        await transporter.sendMail({
          from: '"TurboAir System" <turboairquotes@gmail.com>',
          to: 'andres@turboairmexico.com',
          subject: 'OneDrive Import Failed',
          text: `The scheduled OneDrive Excel import failed with error: ${error.message}`,
          html: `
            <h2>OneDrive Import Failed</h2>
            <p>The scheduled import from OneDrive failed at ${new Date().toISOString()}</p>
            <p><strong>Error:</strong> ${error.message}</p>
            <p>Please check the Firebase Functions logs for more details.</p>
          `
        });
      } catch (emailError) {
        console.error('Failed to send alert email:', emailError.message);
      }

      throw error;
    }
  });

// Manual trigger function for OneDrive import (for testing and manual runs)
exports.triggerOneDriveImport = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      // Verify admin access
      const authHeader = req.headers.authorization;
      if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ error: 'Unauthorized - Bearer token required' });
      }

      const idToken = authHeader.split('Bearer ')[1];
      const decodedToken = await admin.auth().verifyIdToken(idToken);

      // Check if user is admin or super admin
      if (!decodedToken.admin && !decodedToken.superAdmin) {
        return res.status(403).json({ error: 'Forbidden - Admin access required' });
      }

      console.log('Manual OneDrive import triggered by:', decodedToken.email);

      // Get OneDrive share link from request body, environment variable, or use default
      const shareLink = req.body.shareLink ||
                       process.env.ONEDRIVE_SHARE_LINK ||
                       functions.config().onedrive?.share_link ||
                       'https://onedrive.live.com/personal/537ba0d7826179ca/_layouts/15/Doc.aspx?sourcedoc=%7B826179ca-a0d7-207b-8053-2e6a00000000%7D&action=default&redeem=aHR0cHM6Ly8xZHJ2Lm1zL3gvcyFBc3A1WVlMWG9IdFRnZFF1MU5JTGtIRVRicEJoWWc_ZT1MYVBScm4&slrid=9a30cba1-60dd-a000-529b-02f45f3fb372&originalPath=aHR0cHM6Ly8xZHJ2Lm1zL3gvYy81MzdiYTBkNzgyNjE3OWNhL1FjcDVZWUxYb0hzZ2dGTXVhZ0FBQUFBQTFOSUxrSEVUYnBCaFlnP3J0aW1lPVNaUTFxaEVCM2tn&CID=94d7ba4c-9289-4c7b-acf6-67a89815c258&_SRM=0:G:45';

      console.log('Using share link:', shareLink.substring(0, 100) + '...');

      // Download Excel file directly from public OneDrive link
      const excelBuffer = await downloadExcelFromPublicLink(shareLink);

      // Parse Excel data
      const trackingData = parseExcelData(excelBuffer);

      // Import to Firebase
      const result = await importTrackingDataToFirebase(trackingData);

      console.log('Manual import completed successfully:', result);

      return res.status(200).json({
        success: true,
        message: 'OneDrive import completed successfully',
        recordsImported: result.recordsImported,
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      console.error('Manual import failed:', error.message);
      return res.status(500).json({
        success: false,
        error: error.message,
        timestamp: new Date().toISOString()
      });
    }
  });
});

// Function to get import history/logs
exports.getImportLogs = functions.https.onCall(async (data, context) => {
  // Check authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Request must be authenticated'
    );
  }

  // Check if user is admin
  if (!context.auth.token.admin && !context.auth.token.superAdmin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Admin access required'
    );
  }

  try {
    const limit = data.limit || 50;
    const db = admin.database();

    const snapshot = await db.ref('import_logs')
      .orderByChild('timestamp')
      .limitToLast(limit)
      .once('value');

    const logs = [];
    snapshot.forEach((childSnapshot) => {
      logs.push({
        id: childSnapshot.key,
        ...childSnapshot.val()
      });
    });

    // Reverse to show newest first
    logs.reverse();

    return {
      success: true,
      logs: logs,
      count: logs.length
    };
  } catch (error) {
    console.error('Error fetching import logs:', error.message);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to fetch import logs'
    );
  }
});
