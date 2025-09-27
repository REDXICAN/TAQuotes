# 🔐 Security Guide - MANDATORY READING

## ⛔ CRITICAL: 6 Security Violations Already Committed

This project has had **6 security incidents** where credentials were hardcoded and committed to GitHub. This is UNACCEPTABLE and must NEVER happen again.

## 🚨 Before Creating ANY File

Ask yourself:
1. Does this file contain API keys?
2. Does this file contain passwords?
3. Does this file contain email addresses?
4. Does this file contain Firebase configuration?
5. Is this a temporary script for data manipulation?

If YES to any → **DO NOT CREATE THE FILE**

## ❌ FORBIDDEN PATTERNS

### Never Write These in ANY File:

```javascript
// ❌ NEVER - Firebase Config
const firebaseConfig = {
  apiKey: "AIzaSy...",
  authDomain: "taquotes.firebaseapp.com",
  projectId: "taquotes",
  // ... ANY Firebase config
};
```

```dart
// ❌ NEVER - Hardcoded Firebase Options
FirebaseOptions(
  apiKey: "AIzaSy...",
  authDomain: "taquotes.firebaseapp.com",
  // ... ANY hardcoded values
);
```

```python
# ❌ NEVER - Credentials in Scripts
email = "turboairquotes@gmail.com"
password = "any_password_here"
api_key = "AIzaSy..."
```

```html
<!-- ❌ NEVER - HTML with Firebase -->
<script>
  firebase.initializeApp({
    apiKey: "...",
    // ANY Firebase config
  });
</script>
```

## ✅ CORRECT PATTERNS

### Always Use Environment Variables:

```dart
// ✅ CORRECT - Dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Config {
  static String get apiKey => dotenv.env['FIREBASE_API_KEY'] ?? '';
  static String get email => dotenv.env['EMAIL_ADDRESS'] ?? '';
  static String get password => dotenv.env['EMAIL_PASSWORD'] ?? '';
}
```

```javascript
// ✅ CORRECT - JavaScript
require('dotenv').config();

const config = {
  apiKey: process.env.FIREBASE_API_KEY,
  email: process.env.EMAIL_ADDRESS,
  password: process.env.EMAIL_PASSWORD
};
```

```python
# ✅ CORRECT - Python
import os
from dotenv import load_dotenv

load_dotenv()

api_key = os.getenv('FIREBASE_API_KEY')
email = os.getenv('EMAIL_ADDRESS')
password = os.getenv('EMAIL_PASSWORD')
```

## 📋 Pre-Commit Checklist

**RUN THESE COMMANDS BEFORE EVERY COMMIT:**

```bash
# 1. Check for secrets in staged files
git diff --cached | grep -E "(apiKey|AIzaSy|password|PASSWORD|@gmail|@turboair)"

# 2. Check for forbidden files
git ls-files | grep -E "(populate_stock|firebase_config|setup_admin)"

# 3. Run security check script
./check_secrets.sh  # Linux/Mac
check_secrets.bat   # Windows

# 4. Review all new files
git status --porcelain | grep "^A"
```

## 🚫 Files That Must NEVER Be Created

- `populate_stock.html`
- `populate_stock_firebase.dart`
- `firebase_config.js`
- `setup_admin.py`
- `create_admin_user.dart`
- Any HTML file with Firebase config
- Any temporary script with credentials
- Any file ending in `_test.html`

## 🔒 Environment Variables (.env)

The ONLY place for sensitive data:

```env
# .env file (NEVER commit this)
ADMIN_EMAIL=andres@turboairmexico.com
ADMIN_PASSWORD=[secure-password]
EMAIL_SENDER_ADDRESS=turboairquotes@gmail.com
EMAIL_APP_PASSWORD=[app-specific-password]
FIREBASE_API_KEY=[your-api-key]
FIREBASE_AUTH_DOMAIN=taquotes.firebaseapp.com
FIREBASE_DATABASE_URL=https://taquotes-default-rtdb.firebaseio.com
FIREBASE_PROJECT_ID=taquotes
FIREBASE_STORAGE_BUCKET=taquotes.appspot.com
FIREBASE_MESSAGING_SENDER_ID=[your-sender-id]
FIREBASE_APP_ID=[your-app-id]
```

## 🛡️ Git Security

### If You Accidentally Commit Secrets:

1. **DO NOT PUSH** - Stop immediately
2. Reset to before the bad commit:
   ```bash
   git reset --hard HEAD~1
   ```
3. If already pushed, you MUST:
   ```bash
   # Remove from history
   git reset --hard [commit-before-secrets]
   git push --force-with-lease

   # Regenerate all exposed credentials
   # Notify the team immediately
   ```

### Configure Git to Prevent Secrets:

```bash
# Install pre-commit hook
cp check_secrets.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

## 📊 Security Incident History

| Date | Incident | Impact |
|------|----------|--------|
| Aug 26, 2024 | Hardcoded credentials | Dev environment broken |
| Aug 27, 2024 | Wrong Firebase path | Complete database deletion |
| Jan 26, 2025 | API keys in populate_stock.html | Git history contaminated |
| Jan 26, 2025 | Firebase config in .dart file | Force push required |

## ⚠️ Final Warning

**Trust Status: COMPROMISED**

Due to repeated security violations, extra precautions are mandatory:
1. Every file creation must be reviewed
2. No temporary scripts with any configuration
3. Always use environment variables
4. Run security checks before every commit
5. When in doubt, DON'T CREATE THE FILE

**Remember: The app is LIVE in production. A security breach affects real users and real business.**

---
*Last Updated: January 26, 2025*
*Security Violations: 6*
*Required Reading: YES*