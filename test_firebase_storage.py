import firebase_admin
from firebase_admin import credentials, storage
import os

# Initialize Firebase Admin SDK
SERVICE_ACCOUNT_PATH = r'C:\Users\andre\Desktop\-- Flutter App\firebase-admin-key.json'

if not os.path.exists(SERVICE_ACCOUNT_PATH):
    print("ERROR: Firebase service account key not found!")
    exit(1)

try:
    # Initialize Firebase
    cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
    firebase_admin.initialize_app(cred, {
        'databaseURL': 'https://taquotes-default-rtdb.firebaseio.com',
        'storageBucket': 'taquotes.firebasestorage.app'
    })
    
    # Try to get the storage bucket
    bucket = storage.bucket()
    
    print(f"Bucket object created: {bucket}")
    print(f"Bucket name: {bucket.name}")
    
    # Try to actually access the bucket
    try:
        # Test if we can list blobs (will fail if bucket doesn't exist)
        blobs = list(bucket.list_blobs(max_results=1))
        print("SUCCESS! Firebase Storage bucket exists and is accessible.")
        print(f"Bucket name: {bucket.name}")
        print("\nYou can now run the upload scripts:")
        print("1. python upload_sample_images.py    # Test with 3 sample images")
        print("2. python upload_images_to_firebase.py    # Upload all 3,534 images")
    except Exception as list_error:
        print(f"WARNING: Bucket object was created but bucket doesn't actually exist.")
        print(f"Error when trying to list blobs: {list_error}")
        raise list_error
    
except Exception as e:
    print(f"ERROR: Firebase Storage is not yet enabled.")
    print(f"Details: {e}")
    print("\nPlease follow these steps:")
    print("1. Go to https://console.firebase.google.com/project/taquotes/storage")
    print("2. Click 'Get Started'")
    print("3. Choose a location (us-central1 recommended)")
    print("4. Click 'Done'")
    print("5. Run this script again to verify")