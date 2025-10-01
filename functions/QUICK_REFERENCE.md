# OneDrive Excel Import - Quick Reference Card

## 🚀 Quick Start

```bash
# 1. Install dependencies
cd functions && npm install

# 2. Configure .env
cp .env.example .env
# Edit .env with your credentials

# 3. Set Firebase config
cd ..
firebase functions:config:set \
  microsoft.tenant_id="YOUR_TENANT_ID" \
  microsoft.client_id="YOUR_CLIENT_ID" \
  microsoft.client_secret="YOUR_SECRET" \
  onedrive.share_link="YOUR_SHARE_LINK"

# 4. Deploy
firebase deploy --only functions

# 5. Monitor
firebase functions:log --only scheduledOneDriveImport --follow
```

## 📋 Required Environment Variables

```bash
MICROSOFT_TENANT_ID=common
MICROSOFT_CLIENT_ID=12345678-1234-1234-1234-123456789abc
MICROSOFT_CLIENT_SECRET=your-secret-value
ONEDRIVE_SHARE_LINK=https://onedrive.live.com/personal/...
```

## 🔗 OneDrive Share Link

```
https://onedrive.live.com/personal/537ba0d7826179ca/_layouts/15/Doc.aspx?sourcedoc=%7B826179ca-a0d7-207b-8053-2e6a00000000%7D&action=default
```

## 📦 Cloud Functions

| Function | Type | Access | Purpose |
|----------|------|--------|---------|
| `scheduledOneDriveImport` | Scheduled | Automatic | Import every 30 min |
| `triggerOneDriveImport` | HTTP | Admin only | Manual trigger |
| `getImportLogs` | Callable | Admin only | View import history |

## 🗂️ Database Structure

```
/tracking
  └── TRACKING_NUMBER
      ├── tracking_number
      ├── status
      ├── ship_date
      ├── customer_name
      ├── customer_email
      ├── imported_at
      └── last_updated

/import_logs
  └── -PUSH_ID
      ├── type
      ├── records_count
      ├── timestamp
      └── status
```

## 🔍 Common Commands

### Deploy
```bash
firebase deploy --only functions
firebase deploy --only functions:scheduledOneDriveImport
```

### Monitor
```bash
# View logs
firebase functions:log --only scheduledOneDriveImport

# Stream logs
firebase functions:log --follow

# Last 50 entries
firebase functions:log -n 50
```

### Test
```bash
# Manual trigger
curl -X POST https://us-central1-taquotes.cloudfunctions.net/triggerOneDriveImport \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json"

# Check data
firebase database:get /tracking --limit-to-last 5

# Check logs
firebase database:get /import_logs --limit-to-last 5
```

### Config
```bash
# View config
firebase functions:config:get

# Set config
firebase functions:config:set microsoft.client_secret="NEW_SECRET"

# Update after config change
firebase deploy --only functions
```

## 🐛 Troubleshooting

| Issue | Quick Fix |
|-------|-----------|
| Missing credentials error | `firebase functions:config:get` to verify |
| Auth error | Check client secret hasn't expired |
| Download failed | Verify OneDrive share link in browser |
| Not scheduled | `gcloud services enable cloudscheduler.googleapis.com` |
| No logs | Wait 30 minutes or trigger manually |

## 📊 Monitoring Checklist

- [ ] Check logs: `firebase functions:log`
- [ ] Verify data: `firebase database:get /tracking`
- [ ] Check import logs: `firebase database:get /import_logs`
- [ ] Test manual trigger
- [ ] Verify email alerts work

## 🔐 Security Checklist

- [ ] `.env` in `.gitignore`
- [ ] No secrets in Git
- [ ] Firebase config set
- [ ] Database rules deployed
- [ ] Admin-only access configured
- [ ] Client secret expiration tracked

## 📖 Documentation Files

| File | Purpose |
|------|---------|
| `MICROSOFT_GRAPH_SETUP.md` | Azure AD setup |
| `ENVIRONMENT_SETUP.md` | Configuration |
| `DEPLOYMENT_GUIDE.md` | Deployment steps |
| `ONEDRIVE_IMPORT_README.md` | Usage & integration |
| `QUICK_REFERENCE.md` | This file |

## 🔗 Important URLs

- Firebase Console: https://console.firebase.google.com/project/taquotes
- Azure Portal: https://portal.azure.com
- Microsoft Graph: https://docs.microsoft.com/en-us/graph/

## 📧 Support

- Email: andres@turboairmexico.com
- Project: taquotes
- Region: us-central1

## ⏰ Schedule

- **Frequency**: Every 30 minutes
- **Timezone**: America/Mexico_City
- **Next run**: Check Cloud Scheduler

## 💰 Cost Estimate

- **Execution**: 48 times/day
- **Estimated**: $0-$5/month
- **Free tier**: 2M invocations/month

## 🎯 Quick Tests

### Test 1: Local
```bash
firebase emulators:start --only functions
curl -X POST http://localhost:5001/taquotes/us-central1/triggerOneDriveImport \
  -H "Authorization: Bearer TOKEN"
```

### Test 2: Production
```bash
firebase deploy --only functions:triggerOneDriveImport
# Use Flutter app or curl to trigger
```

### Test 3: Scheduled
```bash
gcloud scheduler jobs run firebase-schedule-scheduledOneDriveImport-us-central1
```

## 📝 Flutter Integration

```dart
// Read tracking data
final ref = FirebaseDatabase.instance.ref('tracking');
final snapshot = await ref.get();

// Listen to changes
ref.onValue.listen((event) {
  // Handle updates
});

// Get specific record
final record = await ref.child(trackingNumber).get();
```

## ✅ Pre-Deployment Checklist

- [ ] Dependencies installed (`npm install`)
- [ ] `.env` configured
- [ ] Firebase config set
- [ ] Microsoft Graph API setup complete
- [ ] OneDrive file accessible
- [ ] Local test passed
- [ ] Database rules deployed

## 🚦 Status Indicators

**Green (All Good)**:
- Import logs show `status: "success"`
- Function logs show no errors
- Data appearing in `/tracking`
- Email alerts not received

**Yellow (Warning)**:
- Occasional failures in logs
- Slow execution times (>20s)
- Email alerts for some imports

**Red (Action Required)**:
- Multiple consecutive failures
- Error: "Missing credentials"
- Error: "Failed to authenticate"
- No data in `/tracking` after 1 hour

## 🔄 Update Process

```bash
# 1. Update code
vim functions/index.js

# 2. Test locally
firebase emulators:start --only functions

# 3. Deploy
firebase deploy --only functions

# 4. Monitor
firebase functions:log --follow
```

## 📞 Emergency Contacts

If something breaks:
1. Check function logs
2. Check import logs in database
3. Try manual trigger
4. Contact: andres@turboairmexico.com

## 🎓 Learning Resources

- **Microsoft Graph**: https://docs.microsoft.com/en-us/graph/
- **Firebase Functions**: https://firebase.google.com/docs/functions
- **Cloud Scheduler**: https://cloud.google.com/scheduler/docs
- **XLSX Package**: https://www.npmjs.com/package/xlsx

## 🔧 Maintenance Schedule

**Daily**: Check import logs

**Weekly**: Review function logs

**Monthly**:
- Update dependencies
- Check credential expiration
- Review costs

**Quarterly**:
- Rotate secrets
- Update documentation
- Performance review

---

**Version**: 1.0.0
**Last Updated**: October 1, 2025
**Status**: Production Ready
