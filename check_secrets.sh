#!/bin/bash
# Pre-commit security check script
# Prevents accidental commit of secrets and credentials

echo "🔐 Running security checks..."

# Check for API keys and Firebase config
if git diff --cached | grep -qE "(apiKey|AIzaSy|authDomain|projectId|messagingSenderId|appId|measurementId)"; then
    echo "❌ ERROR: Firebase configuration detected in staged files!"
    echo "Remove Firebase config and use environment variables instead."
    exit 1
fi

# Check for email addresses and passwords
if git diff --cached | grep -qE "(@gmail\.com|@turboairmexico\.com|password|PASSWORD|EMAIL_APP_PASSWORD)"; then
    echo "❌ ERROR: Email addresses or passwords detected in staged files!"
    echo "Remove credentials and use environment variables instead."
    exit 1
fi

# Check for forbidden file patterns
FORBIDDEN_FILES=$(git diff --cached --name-only | grep -E "(populate_stock|firebase_config|setup_admin|firebase_import)")
if [ ! -z "$FORBIDDEN_FILES" ]; then
    echo "❌ ERROR: Forbidden files detected:"
    echo "$FORBIDDEN_FILES"
    echo "These files often contain secrets and should not be committed."
    exit 1
fi

# Check for HTML files with potential Firebase config
HTML_FILES=$(git diff --cached --name-only | grep -E "\.html$")
if [ ! -z "$HTML_FILES" ]; then
    for file in $HTML_FILES; do
        if grep -qE "(firebase|apiKey|authDomain)" "$file" 2>/dev/null; then
            echo "❌ ERROR: HTML file with potential Firebase config: $file"
            echo "HTML files with Firebase config should never be committed."
            exit 1
        fi
    done
fi

# Check for Dart files with FirebaseOptions hardcoded
DART_FILES=$(git diff --cached --name-only | grep -E "\.dart$")
if [ ! -z "$DART_FILES" ]; then
    for file in $DART_FILES; do
        if grep -qE "FirebaseOptions\s*\(" "$file" 2>/dev/null && grep -qE "apiKey:\s*['\"]" "$file" 2>/dev/null; then
            echo "❌ ERROR: Dart file with hardcoded FirebaseOptions: $file"
            echo "Use firebase_options.dart or environment variables instead."
            exit 1
        fi
    done
fi

echo "✅ Security checks passed!"
exit 0