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
          
          productsText += `- ${product.sku || 'N/A'} - ${product.name || 'Unknown'} (Qty: ${quantity}) - $${unitPrice.toFixed(2)} each = $${total.toFixed(2)}\n`;
          
          productsHtml += `
            <tr>
              <td style="padding: 8px; border: 1px solid #ddd; white-space: nowrap;">${product.sku || 'N/A'}</td>
              <td style="padding: 8px; border: 1px solid #ddd;">${product.name || 'Unknown'}</td>
              <td style="padding: 8px; text-align: center; border: 1px solid #ddd;">${quantity}</td>
              <td style="padding: 8px; text-align: right; border: 1px solid #ddd; white-space: nowrap;">$${unitPrice.toFixed(2)}</td>
              <td style="padding: 8px; text-align: right; border: 1px solid #ddd; white-space: nowrap;">$${total.toFixed(2)}</td>
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
- Total Amount: $${parseFloat(totalAmount).toFixed(2)}
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
