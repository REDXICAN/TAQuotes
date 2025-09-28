# Firebase Admin SDK Setup for populate_turboair.js

## Prerequisites

1. **Install Google Cloud CLI**
   ```bash
   # Download from: https://cloud.google.com/sdk/docs/install
   # Or use package manager:
   # Windows: choco install gcloudsdk
   # macOS: brew install google-cloud-sdk
   ```

2. **Authenticate with Google Cloud**
   ```bash
   # Login to Google Cloud
   gcloud auth login

   # Set application default credentials
   gcloud auth application-default login

   # Set the project
   gcloud config set project taquotes
   ```

3. **Verify Setup**
   ```bash
   # Check current project
   gcloud config get-value project

   # Test Firebase access
   gcloud firebase projects list
   ```

## Running the Script

Once authenticated, run the population script:

```bash
cd "C:\Users\andre\Desktop\-- Flutter App"
node populate_turboair.js
```

## What the Script Does

✅ **Creates 10 TurboAir Users:**
- Carlos Rodriguez (carlos@turboair-monterrey.com) - Senior Sales
- Maria Gonzalez (maria@turboair.mx) - Sales Rep
- Juan Martinez (juan@turboair.mx) - Sales Rep
- Ana Lopez (ana@turboair-cancun.mx) - Sales Rep
- Pedro Sanchez (pedro@turboair.mx) - Technical Sales
- Luis Hernandez (luis@turboair.mx) - Distributor
- Sofia Ramirez (sofia@turboair.mx) - Sales Rep
- Diego Torres (diego@turboair.mx) - Senior Sales
- Isabella Flores (isabella@turboair.mx) - Sales Rep
- Miguel Castro (miguel@turboair.mx) - Regional Manager

✅ **For Each User:**
- 2 closed quotes using existing clients and products
- 3 in-progress quotes using existing clients and products
- 2-3 projects linked to existing clients
- Realistic Mexican company data and locations

✅ **Security Features:**
- Uses environment variables from .env file
- No hardcoded credentials
- Uses Application Default Credentials
- Proper error handling and logging

## Troubleshooting

**Error: "Firebase Admin SDK initialization failed"**
- Run: `gcloud auth application-default login`
- Ensure project is set: `gcloud config set project taquotes`

**Error: "Insufficient permissions"**
- Contact admin to grant Firebase Admin permissions
- Verify you have access to the taquotes project

**Error: "Email already exists"**
- Script handles this gracefully and uses existing users
- Safe to re-run multiple times