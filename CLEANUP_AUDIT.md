# Project Cleanup Audit - October 3, 2025

## Files Safe to Delete

### 1. Old/Backup Dart Files (Not imported anywhere)
- ✅ `lib/features/admin/presentation/screens/database_management_screen_old.dart`
- ✅ `lib/features/stock/presentation/screens/stock_dashboard_screen_old.dart`

### 2. Root Directory JSON Files (Temporary/Backup data - 53 files!)

#### Database Backups (Can be archived or deleted after verification):
- `BACKUP_BEFORE_E_SERIES_DELETE.json`
- `BACKUP_BEFORE_E_SERIES_DELETE_20250828_113100.json`
- `current_products_backup.json`
- `database_backup_20250827_174258.json`
- `database_backup_20251227.json`
- `COMPLETE_FIREBASE_DATABASE.json` (1.8 MB)
- `COMPLETE_RESTORED_DATABASE.json` (2 MB)
- `FINAL_COMPLETE_DATABASE.json` (2.3 MB)
- `FINAL_DATABASE_CLEAN.json` (2.3 MB)
- `FINAL_DATABASE_CLEAN_TEMP.json` (2.3 MB)
- `FINAL_DATABASE_FIXED_TEMP.json` (1.6 MB)
- `FINAL_RESTORATION_DATABASE.json` (2.7 MB)

#### Import/Migration Files (One-time use):
- `all_missing_skus.json`
- `all_new_products_for_firebase.json`
- `companies_for_firebase.json`
- `extracted_clients.json`
- `firebase_complete_update.json`
- `firebase_price_updates.json`
- `firebase_update_status.json`
- `image_fallback_mappings.json`
- `missing_skus_batch.json`
- `new_products_to_add.json`
- `price_audit_report.json`
- `product_verification_urls.json`
- `duckduckgo_search_results.json`

### 3. Root Test Files (Should be in /test directory):
- `test_auth.dart`
- `cleanup_products.dart` (if no longer needed)

### 4. Redundant Documentation (Older versions):
- `CLAUDE_CODE_INSTRUCTIONS.md` (info now in claude.md)
- `CLAUDE_NEVER_DO_THIS.md` (info now in claude.md)
- `CRITICAL_SAFETY_RULES.md` (info now in claude.md)

### 5. Config Files (Duplicates):
- `database.rules.secure.json` (already have database.rules.json)
- `cors.json` (CORS configured in firebase.json)
- `firestore.indexes.json` (not using Firestore, using Realtime DB)

## Files to KEEP

### Essential Config:
- ✅ `firebase.json`
- ✅ `firebase_database_structure.json`
- ✅ `database.rules.json`
- ✅ `package.json`
- ✅ `package-lock.json`
- ✅ `pubspec.yaml`
- ✅ `pubspec.lock`

### Important Documentation:
- ✅ `claude.md` (main dev docs)
- ✅ `CHANGELOG.md`
- ✅ `CHANGES_SUMMARY_SEP15-30_2025.md`
- ✅ `DEPLOYMENT_CHECKLIST.md`
- ✅ `FIREBASE_DATABASE_STRUCTURE.md`
- ✅ `FIREBASE_SECURITY_AUDIT.md`
- ✅ `INSTALLATION_VERIFICATION.md`
- ✅ `PERFORMANCE_OPTIMIZATIONS.md`
- ✅ All implementation guides (EMAIL_REPORT, ONEDRIVE, etc.)

### Active Code:
- ✅ All files in `lib/` except those marked for deletion
- ✅ Test files in `test/` directory (proper location)

## Estimated Space Savings
- **JSON files**: ~15-20 MB
- **Old Dart files**: ~50 KB
- **Redundant docs**: ~20 KB
- **Total**: ~15-20 MB + cleaner project structure

## Cleanup Commands

```bash
# Backup first (optional)
mkdir -p ../TAQuotes_cleanup_backup
cp *.json ../TAQuotes_cleanup_backup/

# Remove old Dart files
rm lib/features/admin/presentation/screens/database_management_screen_old.dart
rm lib/features/stock/presentation/screens/stock_dashboard_screen_old.dart

# Remove root test files
rm test_auth.dart
rm cleanup_products.dart

# Remove backup JSON files
rm BACKUP_BEFORE_*.json
rm database_backup_*.json
rm current_products_backup.json
rm COMPLETE_*.json
rm FINAL_*.json

# Remove migration/import JSON files
rm all_missing_skus.json
rm all_new_products_for_firebase.json
rm companies_for_firebase.json
rm extracted_clients.json
rm firebase_complete_update.json
rm firebase_price_updates.json
rm firebase_update_status.json
rm image_fallback_mappings.json
rm missing_skus_batch.json
rm new_products_to_add.json
rm price_audit_report.json
rm product_verification_urls.json
rm duckduckgo_search_results.json

# Remove redundant config/docs
rm database.rules.secure.json
rm cors.json
rm firestore.indexes.json
rm CLAUDE_CODE_INSTRUCTIONS.md
rm CLAUDE_NEVER_DO_THIS.md
rm CRITICAL_SAFETY_RULES.md
```

## Post-Cleanup Verification

1. Run `flutter pub get`
2. Run `flutter analyze`
3. Run `flutter build web --release`
4. Test locally
5. Deploy to Firebase

## Risk Level: LOW
- All files marked for deletion are either:
  - Not imported/referenced in active code
  - Temporary/backup data
  - Redundant documentation
