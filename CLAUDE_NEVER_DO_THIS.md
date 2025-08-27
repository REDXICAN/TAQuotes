# ⛔ CLAUDE - NEVER MAKE THESE MISTAKES AGAIN ⛔

## YOU JUST DESTROYED A PRODUCTION DATABASE - TWICE

### MISTAKE #1: DELETED ENTIRE DATABASE
- **What you did:** Told user to import JSON without specifying to import at `/products` node
- **Result:** Wiped out entire database including clients, users, quotes
- **Correct way:** ALWAYS specify exact path: "Import to `/products` node ONLY"

### MISTAKE #2: DELETED .venv (Yesterday)
- **What you did:** Suggested deleting Python virtual environment
- **Result:** Broke the entire development environment
- **Correct way:** NEVER suggest deleting environment files

## MANDATORY RULES - FOLLOW OR FAIL

### Before ANY Firebase operation:
```
1. BACKUP: firebase database:get "/" > BACKUP_[timestamp].json
2. VERIFY: Check current structure
3. SPECIFY: Exact node path (/products, /clients, etc)
4. WARN: "This will REPLACE data at [path]"
5. TEST: Try with 5 items first
```

### Firebase Import - ALWAYS SAY THIS:
```
⚠️ CRITICAL: Import to specific node, NOT root!
- If importing products: Select /products node
- If importing clients: Select /clients node  
- NEVER import at root (/) level
- Root import = DELETE EVERYTHING
```

### NEVER say:
- "Import this to Firebase"
- "Update the database"
- "Import JSON"

### ALWAYS say:
- "Import this to /products node in Firebase"
- "This will ONLY update the products, not clients/users"
- "Make sure path shows /products before importing"

## YOU ARE DEALING WITH:
- **REAL BUSINESS DATA**
- **REAL MONEY** ($200/month subscription)
- **REAL USERS** (500+ sales reps)
- **PRODUCTION SYSTEM** (not a test environment)

## CONSEQUENCES OF YOUR MISTAKES:
- Lost customer data
- Broken business operations
- Hours of recovery work
- Loss of user trust
- Potential business losses

## YOUR PROMPT FOR FUTURE:

"I am working on a PRODUCTION Firebase database. Before suggesting ANY database operation, I MUST:
1. Create backup instructions FIRST
2. Specify EXACT node paths (never root)
3. Warn about data replacement
4. Provide recovery plan BEFORE operation
5. Test with small batch first

I will NEVER tell someone to import at root level or delete environment files."

## REMEMBER:
**Every instruction you give can destroy someone's business. Think three times, verify twice, then add more warnings.**