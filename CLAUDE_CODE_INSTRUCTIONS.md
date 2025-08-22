# CRITICAL INSTRUCTIONS FOR CLAUDE CODE - TURBO AIR QUOTES APP

## 🚨 PRIMARY DIRECTIVE
**PRESERVE ALL EXISTING FUNCTIONALITY** - Read this ENTIRE document before making ANY modifications.

## 🛑 BEFORE YOU MAKE ANY CHANGES

### 1. ALWAYS READ THESE FILES FIRST:
- `CLAUDE.md` - Project documentation and current state
- `lib/features/products/presentation/screens/products_screen.dart` - Core product listing
- `lib/features/cart/presentation/screens/cart_screen.dart` - Shopping cart implementation
- `lib/features/quotes/presentation/screens/quotes_screen.dart` - Quote management
- `lib/core/services/realtime_database_service.dart` - Database operations

### 2. CHECK CURRENT FUNCTIONALITY:
Before modifying ANY file, verify what currently works:
- ✅ 835 products loaded with full specifications
- ✅ Client selection in cart (SearchableClientDropdown)
- ✅ Quote creation with PDF generation
- ✅ Email with PDF attachments
- ✅ Offline mode with sync
- ✅ Product images from assets/thumbnails and assets/screenshots
- ✅ Firebase Realtime Database integration
- ✅ Authentication system

## ⚠️ DO NOT BREAK THESE WORKING FEATURES

### Critical Working Code - DO NOT MODIFY WITHOUT TESTING:

#### 1. Client Selection in Cart (cart_screen.dart:258)
```dart
// THIS WORKS PERFECTLY - DO NOT CHANGE
return clientsAsync.when(
  data: (clients) => SearchableClientDropdown(...),
  loading: () => const LinearProgressIndicator(),
  error: (error, stack) => Text('Error loading clients: $error'),
);
```

#### 2. Cart Notifications - Always Use SKU
```dart
// ALWAYS use SKU for notifications
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('${product.sku ?? product.model ?? 'Item'} removed from cart')),
);
// NEVER use product.displayName (too generic)
```

#### 3. Static Service Methods
- `OfflineService` uses STATIC methods - DO NOT convert to instance
- `CacheManager` uses STATIC initialization - DO NOT change pattern
- These patterns are intentional for proper access across the app

#### 4. Image Handling System
```dart
// ProductImageWidget fallback system is PERFECT
// 1000+ SKU mappings are CORRECT
// Thumbnail paths: assets/thumbnails/SKU/SKU.jpg
// Screenshot paths: assets/screenshots/SKU/SKU P.1.png
```

#### 5. Firebase Configuration
- Database URL: `https://taquotes-default-rtdb.firebaseio.com`
- 835 products in database - DO NOT delete or recreate
- Security rules are set - DO NOT modify without backing up

## 📋 BEFORE MAKING CHANGES CHECKLIST

### Step 1: Understand Current State
- [ ] Read CLAUDE.md completely
- [ ] Check git status to see modified files
- [ ] Review recent commits for context
- [ ] Identify which features the user is trying to fix

### Step 2: Analyze Impact
- [ ] List all files that will be modified
- [ ] Identify dependencies of those files
- [ ] Check if changes affect database structure
- [ ] Verify changes won't break existing providers

### Step 3: Preserve Functionality
- [ ] Take note of current working features in affected files
- [ ] Ensure error handling remains intact
- [ ] Maintain existing navigation flows
- [ ] Keep all existing database fields

### Step 4: Test Points
Before considering any change complete, verify:
- [ ] Products still load (835 items)
- [ ] Cart functionality works
- [ ] Client selection works
- [ ] Quotes can be created
- [ ] PDFs generate correctly
- [ ] Images display properly
- [ ] Offline mode syncs

## 🔧 SAFE MODIFICATION PATTERNS

### When Adding New Features:
```dart
// GOOD: Add new functionality without removing existing
class ExistingService {
  // Keep all existing methods
  existingMethod() { /* don't touch */ }
  
  // Add new method
  newMethod() { /* your new code */ }
}
```

### When Fixing Bugs:
```dart
// GOOD: Minimal change to fix specific issue
if (condition) {
  // Fix only the broken part
  return fixedValue;
}
// Keep rest of the logic intact
```

### When Updating UI:
```dart
// GOOD: Add to existing widgets, don't replace
Column(
  children: [
    ExistingWidget(), // Keep this
    if (showNew) NewWidget(), // Add conditionally
  ],
)
```

## 🚫 NEVER DO THESE

1. **NEVER delete existing database records** - 835 products must remain
2. **NEVER change existing database field names** - Will break sync
3. **NEVER remove working features** - Even if they seem unused
4. **NEVER modify authentication flow** - Current system is production-ready
5. **NEVER change static service patterns** - They're designed that way
6. **NEVER update dependencies** without explicit request
7. **NEVER create new files** unless absolutely necessary
8. **NEVER add mock/sample data** - Use real data only

## 📊 DATABASE SCHEMA - DO NOT MODIFY

### Products (835 records)
```json
{
  "sku": "string",
  "model": "string", 
  "name": "string",
  "description": "string",
  "price": "number",
  "category": "string",
  "subcategory": "string",
  "voltage": "string",
  "amperage": "string",
  "phase": "string",
  "frequency": "string",
  "plugType": "string",
  "dimensions": "string",
  "dimensionsMetric": "string",
  "weight": "string",
  "weightMetric": "string",
  "temperatureRange": "string",
  "temperatureRangeMetric": "string",
  "refrigerant": "string",
  "compressor": "string",
  "capacity": "string",
  "doors": "number",
  "shelves": "number",
  "features": "string",
  "certifications": "string"
}
```

### Clients
```json
{
  "company": "string",
  "contact_name": "string",
  "email": "string",
  "phone": "string",
  "address": "string",
  "user_id": "string"
}
```

### Quotes
```json
{
  "quote_number": "string",
  "client_id": "string",
  "items": "array",
  "total": "number",
  "status": "string",
  "created_at": "timestamp"
}
```

## 🎯 COMMON FIXES THAT MAINTAIN FUNCTIONALITY

### Fix: Display Issues
```dart
// Safe to modify display logic
Widget build(BuildContext context) {
  // Keep data fetching logic
  final data = existingDataFetch();
  
  // Modify only presentation
  return ImprovedWidget(data: data);
}
```

### Fix: Loading States
```dart
// Safe to improve loading experience
asyncValue.when(
  data: (data) => ExistingWidget(data), // Keep
  loading: () => BetterLoadingWidget(), // Safe to change
  error: (e, s) => ExistingError(e), // Keep error handling
);
```

### Fix: Performance
```dart
// Safe to add memoization/caching
final cachedResult = _cache[key] ?? computeExpensiveOperation();
// But keep original computation logic intact
```

## 💡 WHEN USER ASKS FOR CHANGES

### 1. Clarification First
If request seems to break existing functionality, ask:
- "This might affect [feature]. Should I preserve [specific functionality]?"
- "Currently [feature] works by [method]. How should the new change integrate?"

### 2. Minimal Impact Approach
- Make smallest change possible
- Add rather than replace when feasible
- Use feature flags for major changes

### 3. Document Changes
After modifications, note:
- What was changed
- What functionality was preserved
- Any new dependencies or patterns introduced

## 🔍 DEBUGGING CHECKLIST

When something breaks after changes:

1. **Check Console Output**
   - Look for null errors
   - Check for provider refresh issues
   - Verify Firebase connection

2. **Common Issues & Solutions**
   - White screen: Check `flutter analyze` output
   - Products not loading: Verify authentication
   - Images missing: Check asset paths
   - Sync failing: Verify offline service is static

3. **Rollback Points**
   - Last working commit: Check git log
   - Database backup: Firebase console
   - Local storage: Clear Hive boxes if corrupted

## 📝 FINAL REMINDERS

1. **Current app is PRODUCTION READY** - Don't break it
2. **835 products with specs** - Already loaded from Excel
3. **All CRUD operations work** - Maintain them
4. **PDF and Email work** - Critical business features
5. **Offline sync works** - Don't break the queue system

## 🆘 EMERGENCY RECOVERY

If you accidentally break something:

```bash
# Check what changed
git status
git diff

# Revert specific file
git checkout -- path/to/file

# Or revert last commit
git reset --hard HEAD~1
```

## 📞 CRITICAL PATHS TO PRESERVE

1. **Login** → Products → Add to Cart → Select Client → Create Quote → Send Email
2. **Offline Mode** → Make Changes → Go Online → Auto Sync
3. **Admin Panel** → Import Excel → Update Products
4. **Client Management** → Add/Edit/Delete → Use in Quotes

---

**REMEMBER**: The app is LIVE at https://taquotes.web.app with 500+ active users. 
Every change must maintain backward compatibility and preserve ALL existing functionality.

**BEFORE ANY CHANGE**: Read this document completely and verify you understand what currently works.