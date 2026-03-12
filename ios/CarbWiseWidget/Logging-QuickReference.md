# Logging Quick Reference

## 🚀 Quick Filters for Xcode Console

```
All CarpeCarb logs:        subsystem:com.carpecarb
App lifecycle:             category:AppDelegate
Flutter bridge:            category:CloudSyncChannel
iCloud sync:               category:CloudSyncStore
Widget updates:            category:CarbWiseWidget

Errors only:               type:error
Warnings only:             type:warning
Info only:                 type:info

Push operations:           ⬆️
Pull operations:           ⬇️
Remote changes:            🔔
Errors:                    ❌
Warnings:                  ⚠️
Success:                   ✓
```

## 🐛 Troubleshooting Checklist

### iCloud Sync Issues
```bash
# Check these logs in order:
1. category:AppDelegate             # Is app launching?
2. category:CloudSyncChannel        # Is Flutter calling methods?
3. category:CloudSyncStore          # Is iCloud available?
4. "iCloud availability"            # Specific availability check
5. type:error                       # Any errors?
```

### Widget Not Updating
```bash
1. category:CarbWiseWidget          # Widget logs
2. "Failed to access UserDefaults"  # App Group issue?
3. "Total carbs: 0"                 # No data yet?
4. "Next refresh scheduled"         # When is next update?
```

### Remote Changes Not Working
```bash
1. "startObserving"                 # Did we start?
2. "External change notification"   # Did we receive it?
3. "remote change"                  # Did we notify Flutter?
4. type:error                       # Any errors?
```

## 📊 Common Log Patterns

### ✅ Successful Push
```
📞 Method call received: 'pushToCloud'
⬆️  pushToCloud: Pushing 3 key(s)
✓ pushToCloud: Completed
Successfully pushed to iCloud
```

### ✅ Successful Pull
```
📞 Method call received: 'pullFromCloud'
⬇️  pullFromCloud: Requesting data
✓ pullFromCloud: Retrieved 6 key(s)
```

### ✅ Remote Change
```
External change notification received
Change reason: Server change
Successfully pulled 6 keys from iCloud
🔔 Remote change detected: 6 key(s) changed
✓ Flutter callback completed successfully
```

### ❌ iCloud Unavailable
```
⚠️ Pull aborted: iCloud not available
iCloud availability: false
```

### ❌ Widget Data Missing
```
❌ Failed to access UserDefaults suite
Total carbs: 0.0g
(no goal set)
```

## 💻 Command Line Quick Commands

```bash
# Stream all logs
log stream --predicate 'subsystem == "com.carpecarb"'

# Save to file
log stream --predicate 'subsystem == "com.carpecarb"' > debug.log

# Errors only
log stream --predicate 'subsystem == "com.carpecarb" AND eventType == error'

# Specific category
log stream --predicate 'category == "CloudSyncStore"'

# Last 5 minutes
log show --predicate 'subsystem == "com.carpecarb"' --last 5m
```

## 🎯 Key Indicators

| What to Look For | Meaning |
|------------------|---------|
| `iCloud availability: false` | User not signed in |
| `Already observing` | Duplicate call (harmless) |
| `Quota violation!` | Data exceeded 1MB |
| `Failed to access UserDefaults suite` | App Group misconfigured |
| `No data in iCloud` | First run or no sync yet |
| `Timestamp unchanged` | Duplicate notification (filtered) |

## 📱 Console.app Setup

1. Open Console.app
2. Device → Select your iPhone/Simulator
3. Search field: `subsystem:com.carpecarb`
4. Click **Start**

## 🔍 Advanced Filtering

```
// Combine filters
category:CloudSyncStore AND type:error

// Multiple categories
category:CloudSyncStore OR category:CloudSyncChannel

// Exclude debug
subsystem:com.carpecarb AND type:info

// Time range (Console.app)
subsystem:com.carpecarb AND timeRange:[2026-03-11 15:00:00, 2026-03-11 16:00:00]

// Message content
subsystem:com.carpecarb AND message CONTAINS "push"
```

## 🚨 Red Flags

Look for these ERROR logs:

```
❌ Failed to get plugin registrar for CloudSyncChannel
❌ Failed to access UserDefaults suite
❌ Failed to send remote change to Flutter
❌ Application failed to launch
❌ Quota violation!
```

## ✅ Health Check

A healthy app should show:

```
✅ App Delegate
🚀 Application launching
✓ Application launched successfully
✓ CloudSyncChannel registered successfully

✅ iCloud Sync
iCloud availability: true
✓ pushToCloud: Completed
✓ pullFromCloud: Retrieved X key(s)

✅ Widget
📊 Widget data: XXg / XXg
Next refresh scheduled for: [time]

✅ Observing
👀 startObserving: Now observing
🔔 Remote change detected
✓ Flutter callback completed successfully
```

---

**Pro Tip:** Keep Console.app open during development with filter `subsystem:com.carpecarb` to see real-time logs!
