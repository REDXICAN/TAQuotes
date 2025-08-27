# 🚨 CRITICAL SAFETY RULES - NEVER VIOLATE THESE 🚨

## DATABASE OPERATIONS - EXTREME CAUTION REQUIRED

### ❌ NEVER DO THIS:
1. **NEVER tell user to import JSON at root level "/"**
2. **NEVER suggest "Import JSON" without specifying EXACT path like `/products`**
3. **NEVER say "import to database" - ALWAYS specify "import to /products node"**
4. **NEVER delete or suggest deleting .env, .venv, or environment files**
5. **NEVER assume Firebase operations - ALWAYS verify path and scope**

### ✅ ALWAYS DO THIS:
1. **ALWAYS create backups BEFORE any database operation:**
   ```bash
   firebase database:get "/" > FULL_BACKUP_[date].json
   ```

2. **ALWAYS specify exact Firebase path:**
   - WRONG: "Import this JSON to Firebase"
   - RIGHT: "Import this JSON to `/products` node in Firebase"

3. **ALWAYS warn about data replacement:**
   ```
   ⚠️ WARNING: This will REPLACE all data at [specific path]
   ⚠️ Make sure you're importing to the correct node, not root!
   ```

4. **ALWAYS verify current database structure before operations:**
   ```bash
   firebase database:get "/" --shallow
   ```

5. **ALWAYS test with small batches first**

## FIREBASE IMPORT CHECKLIST - MANDATORY

Before ANY Firebase import instruction:

- [ ] **BACKUP CREATED?** Full database exported to JSON
- [ ] **PATH SPECIFIED?** Exact node path like `/products` stated
- [ ] **WARNING GIVEN?** User warned about data replacement
- [ ] **STRUCTURE VERIFIED?** Checked what will be affected
- [ ] **TEST FILE READY?** Small test batch prepared first

## ENVIRONMENT FILES - NEVER DELETE

### ❌ NEVER suggest deleting:
- `.env` - Contains critical credentials
- `.venv` - Python virtual environment
- `node_modules` - Dependencies
- `firebase.json` - Firebase configuration
- Any config files without backup

### ✅ ALWAYS:
- Check file contents before suggesting modifications
- Create `.backup` versions before changes
- Verify credentials are preserved

## IMPORT INSTRUCTION TEMPLATE (USE THIS ALWAYS)

```markdown
⚠️ **CRITICAL: READ BEFORE IMPORTING** ⚠️

**BACKUP FIRST:**
1. Export current database: firebase database:get "/" > backup_[date].json
2. Verify backup file is created and valid

**IMPORT STEPS:**
1. File to import: [filename]
2. **TARGET PATH: /products** ← VERIFY THIS IS SELECTED
3. Open: https://console.firebase.google.com/project/[project]/database
4. Navigate to the `/products` node specifically
5. Click three dots → Import JSON
6. **CONFIRM PATH shows "/products" before importing**

**THIS WILL REPLACE:** Only the /products data
**THIS WILL NOT AFFECT:** /clients, /users, /quotes, etc.
```

## DAMAGE CONTROL PROTOCOL

If something goes wrong:

1. **IMMEDIATE:** Check for local backups
2. **CHECK:** Firebase automatic backups (if enabled)
3. **SEARCH:** Any JSON exports in project folder
4. **RESTORE:** Create restoration script immediately
5. **APOLOGIZE:** Take full responsibility
6. **DOCUMENT:** What went wrong and how to prevent

## YOUR RESPONSIBILITIES

1. **You are handling PRODUCTION DATA**
2. **Real businesses depend on this data**
3. **Always err on the side of caution**
4. **When in doubt, create backups**
5. **Test operations on small data first**
6. **Be explicit about every risk**

## FIREBASE SPECIFIC RULES

1. **Root level ("/") imports REPLACE ENTIRE DATABASE**
2. **Node level ("/products") imports replace ONLY that node**
3. **Firebase Console doesn't always show current path clearly**
4. **ALWAYS tell user to verify the path before importing**
5. **NEVER assume user knows the difference**

## MANDATORY WARNING TEMPLATE

```
⚠️⚠️⚠️ STOP AND READ ⚠️⚠️⚠️
This operation will PERMANENTLY REPLACE data.
Current path: [specify exact path]
Data affected: [specify what will be replaced]
Data NOT affected: [specify what remains safe]

Create backup first:
firebase database:get "/" > full_backup.json

Proceed only after backup is confirmed.
⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️
```

## REMEMBER

- **User pays $200/month for a WORKING system**
- **One wrong command can destroy hours of work**
- **Trust is earned over months, lost in seconds**
- **Always provide recovery options BEFORE risky operations**
- **Your instructions must be FOOLPROOF**

# THIS IS A PRODUCTION SYSTEM - TREAT IT AS SUCH