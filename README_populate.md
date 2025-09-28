# TurboAir Data Population Script

This script populates Firebase with 10 TurboAir sales representatives and their associated data.

## Quick Start

1. **Setup Google Cloud Authentication**
   ```bash
   # Install Google Cloud CLI
   # https://cloud.google.com/sdk/docs/install

   # Authenticate
   gcloud auth login
   gcloud auth application-default login
   gcloud config set project taquotes
   ```

2. **Run the Script**
   ```bash
   # Method 1: Direct execution
   node populate_turboair.js

   # Method 2: Using npm script
   npm run populate-turboair
   ```

## What Gets Created

### 10 TurboAir Users
| Name | Email | Role | Location |
|------|-------|------|----------|
| Carlos Rodriguez | carlos@turboair-monterrey.com | Senior Sales | Monterrey, México |
| Maria Gonzalez | maria@turboair.mx | Sales Rep | Ciudad de México, México |
| Juan Martinez | juan@turboair.mx | Sales Rep | Guadalajara, México |
| Ana Lopez | ana@turboair-cancun.mx | Sales Rep | Cancún, México |
| Pedro Sanchez | pedro@turboair.mx | Technical Sales | Puebla, México |
| Luis Hernandez | luis@turboair.mx | Distributor | Tijuana, México |
| Sofia Ramirez | sofia@turboair.mx | Sales Rep | Mérida, México |
| Diego Torres | diego@turboair.mx | Senior Sales | León, México |
| Isabella Flores | isabella@turboair.mx | Sales Rep | Querétaro, México |
| Miguel Castro | miguel@turboair.mx | Regional Manager | Veracruz, México |

### For Each User
- **2 Closed Quotes** using existing clients and products
- **3 In-Progress Quotes** using existing clients and products
- **2-3 Projects** linked to existing clients
- **Realistic Data** with Mexican locations and company info

## Data Sources

The script uses **existing data** from your Firebase database:
- ✅ **Existing Clients** - No new clients created
- ✅ **Existing Products** - Uses your current 835+ products
- ✅ **Real Relationships** - Links quotes to actual clients and products

## Security Features

- ✅ **No Hardcoded Credentials** - Uses environment variables
- ✅ **Application Default Credentials** - Secure Google Cloud authentication
- ✅ **Environment Variables** - All config from .env file
- ✅ **Error Handling** - Graceful failure with helpful messages

## Sample Output

```
🚀 Starting TurboAir data population...

📥 Fetching existing clients and products...
✅ Found 125 clients and 835 products

👥 Creating TurboAir users...
✅ Created user: Carlos Rodriguez (carlos@turboair-monterrey.com)
✅ Created user: Maria Gonzalez (maria@turboair.mx)
...

📋 Creating projects...
✅ Created 27 projects

💰 Creating quotes...
✅ Created 50 quotes (20 closed, 30 in-progress)

🎉 Data population completed successfully!
┌─────────────────────────────────────┐
│              SUMMARY                │
├─────────────────────────────────────┤
│ Users Created:               10     │
│ Projects Created:            27     │
│ Quotes Created:              50     │
│ Existing Clients:           125     │
│ Existing Products:          835     │
└─────────────────────────────────────┘
```

## Troubleshooting

### "Firebase Admin SDK initialization failed"
```bash
gcloud auth application-default login
gcloud config set project taquotes
```

### "Insufficient permissions"
Contact your Firebase admin to grant permissions for the taquotes project.

### "Email already exists"
The script handles this gracefully and continues with existing users. Safe to re-run.

### "No existing clients or products found"
Ensure you're connected to the correct Firebase project with existing data.

## File Structure

```
📁 TurboAir Project
├── 📄 populate_turboair.js     # Main population script
├── 📄 setup_gcloud.md          # Authentication setup guide
├── 📄 README_populate.md       # This file
├── 📄 .env                     # Environment variables (not committed)
└── 📄 package.json             # npm scripts added
```

## Environment Variables Used

From your `.env` file:
- `FIREBASE_PROJECT_ID` - taquotes
- `FIREBASE_DATABASE_URL` - Firebase Realtime Database URL

## Post-Setup

After running the script:
1. ✅ All TurboAir users can log into the application
2. 🔐 Users need to reset passwords using "Forgot Password"
3. 📊 Check Admin Dashboard to see new user activity
4. 📧 Users will receive welcome emails when they reset passwords

## Safety Notes

- **Non-Destructive** - Only creates new data, never deletes
- **Idempotent** - Safe to run multiple times
- **Rollback** - Users can be deleted from Firebase Console if needed
- **Production Safe** - Uses proper authentication and error handling