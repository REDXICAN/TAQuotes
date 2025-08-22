import firebase_admin
from firebase_admin import credentials, storage

# Initialize Firebase
cred = credentials.Certificate(r'C:\Users\andre\Desktop\-- Flutter App\firebase-admin-key.json')
app = firebase_admin.initialize_app(cred, {
    'storageBucket': 'taquotes.firebasestorage.app'
}, name='counter')

bucket = storage.bucket(app=app)

# Count files
thumbnail_count = 0
screenshot_count = 0

for blob in bucket.list_blobs():
    if 'thumbnails/' in blob.name:
        thumbnail_count += 1
    elif 'screenshots/' in blob.name:
        screenshot_count += 1

total = thumbnail_count + screenshot_count
print(f"Upload Progress:")
print(f"  Thumbnails: {thumbnail_count}")
print(f"  Screenshots: {screenshot_count}")
print(f"  Total: {total} / ~3534")
print(f"  Progress: {(total/3534)*100:.1f}%")

# Clean up
firebase_admin.delete_app(app)