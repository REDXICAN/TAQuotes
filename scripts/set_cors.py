import subprocess
import json
import sys

# Set UTF-8 encoding for Windows console
if sys.platform == 'win32':
    sys.stdout.reconfigure(encoding='utf-8')

def set_cors():
    """Set CORS configuration for Firebase Storage bucket."""
    
    cors_config = [
        {
            "origin": [
                "https://taquotes.web.app",
                "https://taquotes.firebaseapp.com", 
                "http://localhost:*",
                "http://127.0.0.1:*"
            ],
            "method": ["GET", "HEAD"],
            "maxAgeSeconds": 3600
        }
    ]
    
    # Write CORS config to file
    with open('../cors.json', 'w') as f:
        json.dump(cors_config, f, indent=2)
    
    print('📋 CORS configuration created')
    print('⚠️  To apply CORS configuration, you need to:')
    print()
    print('1. Install Google Cloud SDK from: https://cloud.google.com/sdk/docs/install')
    print('2. Run: gcloud auth login')
    print('3. Run: gsutil cors set cors.json gs://taquotes.firebasestorage.app')
    print()
    print('OR use Firebase Console:')
    print('1. Go to: https://console.firebase.google.com/project/taquotes/storage')
    print('2. Click on the three dots menu for your bucket')
    print('3. Select "Edit bucket" and configure CORS')
    print()
    print('Alternative: Use Firebase Storage signed URLs instead of direct URLs')

if __name__ == '__main__':
    set_cors()