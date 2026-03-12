# Logging & Debugging Guide for CarpeCarb

## Overview

Comprehensive logging has been added throughout the CarpeCarb project to make debugging easier. All logs use Apple's unified logging system (`os.log`) with categorized subsystems.

---

## 📊 Logging Architecture

### **Subsystem & Categories**

All logs use the subsystem: `com.carpecarb`

| Component | Category | Purpose |
|-----------|----------|---------|
| **AppDelegate** | `AppDelegate` | App lifecycle events |
| **CloudSyncChannel** | `CloudSyncChannel` | Flutter ↔ Native bridge |
| **CloudSyncStore** | `CloudSyncStore` | iCloud sync operations |
| **CarbWiseWidget** | `CarbWiseWidget` | Widget data loading & timeline |

---

## 🎨 Emoji Legend

Logs use emojis for quick visual scanning:

| Emoji | Meaning | Log Level |
|-------|---------|-----------|
| 📱 | Initialization/Setup | info |
| 🚀 | Launch/Start | info |
| 🔧 | Configuration | info/debug |
| ✓ | Success | info |
| ✅ | Completion | info |
| 📞 | Method call | debug |
| ⬆️ | Upload/Push | info |
| ⬇️ | Download/Pull | info |
| 👀 | Start observing | info |
| 🔔 | Notification/Event | info |
| 🛑 | Stop/Termination | info |
| ℹ️ | Information | info |
| ⚠️ | Warning | warning |
| ❌ | Error | error |
| 📴 | Resign active | info |
| ⏸️ | Background | info |
| ▶️ | Foreground | info |
| 📊 | Data/Stats | info |
| 📸 | Snapshot | info |
| ⏰ | Timeline | info |
| 📖 | Loading | debug |
| 🔚 | Cleanup/Deinit | debug |

---

## 📱 AppDelegate Logs

### **What's Logged:**
- Application launch and termination
- Flutter engine initialization
- Plugin registration
- App lifecycle transitions (background, foreground, etc.)

### **Example Output:**
```
🚀 Application launching
✓ Application launched successfully
🔧 Initializing implicit Flutter engine
✓ Generated plugins registered
✓ Plugin registrar obtained for CloudSyncChannel
📱 CloudSyncChannel initialized on channel 'com.carpecarb/cloudsync'
✓ CloudSyncChannel registered successfully
```

### **View in Xcode Console:**
```
Filter: category:AppDelegate
```

### **View in Console.app:**
```
subsystem:com.carpecarb category:AppDelegate
```

---

## 🌐 CloudSyncChannel Logs

### **What's Logged:**
- All Flutter method calls
- Data being synced (keys and types)
- Success/failure of operations
- Observer lifecycle
- Remote change notifications

### **Example Output:**
```
📞 Method call received: 'pushToCloud'
⬆️  pushToCloud: Pushing 3 key(s): [food_items, daily_carb_goal, last_save_date]
   food_items: Array (5 items)
   daily_carb_goal: Double
   last_save_date: String (24 chars)
✓ pushToCloud: Completed

📞 Method call received: 'startObserving'
👀 startObserving: Starting to observe iCloud changes
✓ startObserving: Now observing

🔔 Remote change detected: 3 key(s) changed: [food_items, daily_carb_goal, cloud_last_modified]
   Invoking Flutter callback 'onRemoteChange'
   ✓ Flutter callback completed successfully
```

### **View in Xcode Console:**
```
Filter: category:CloudSyncChannel
```

### **Common Warnings:**
- `⚠️ startObserving: Already observing - ignoring duplicate call`
- `⚠️ pushToCloud: Empty data dictionary`
- `❌ pushToCloud: Invalid arguments type - expected dictionary`

---

## ☁️ CloudSyncStore Logs

### **What's Logged:**
- iCloud availability checks
- Push/pull operations with timestamps
- NotificationCenter events
- Change reasons (server, initial sync, quota violation, account change)
- Duplicate notification prevention

### **Example Output:**
```
iCloud availability checked: true
Pushing 5 keys to iCloud
Set key 'food_items'
Set key 'saved_foods'
Set key 'daily_carb_goal'
Set key 'daily_reset_hour'
Set key 'last_save_date'
Successfully pushed to iCloud (timestamp: 2026-03-11T15:30:00Z)

External change notification received
Change reason: Server change
Changed keys: food_items, daily_carb_goal
Successfully pulled 6 keys from iCloud (timestamp: 2026-03-11T15:30:00Z)
Notifying of remote change
```

### **View in Xcode Console:**
```
Filter: category:CloudSyncStore
```

### **Change Reasons:**
- `Server change` - Another device pushed changes
- `Initial sync` - First sync after enabling iCloud
- `Quota violation` - Exceeded 1MB limit (ERROR level)
- `Account change` - User switched iCloud accounts

---

## 🎛️ CarbWiseWidget Logs

### **What's Logged:**
- Timeline requests and updates
- Data loading from UserDefaults
- Widget refresh scheduling
- Data statistics (carbs, goals, percentages)

### **Example Output:**
```
⏰ Timeline requested for widget family: systemSmall
📖 Loading data from UserDefaults suite: 'group.com.jamesaguero.mycarbtracker'
   Total carbs: 42.5g
   Last food: 'Brown Rice' (15.0g)
   Daily goal: 100.0g
📊 Widget data (timeline): 42.5g / 100.0g (43%) - 57.5g remaining
   Last logged: Brown Rice (15.0g)
Next refresh scheduled for: Mar 11, 2026 at 3:45 PM
```

### **View in Xcode Console:**
```
Filter: category:CarbWiseWidget
```

### **Common Issues:**
- `❌ Failed to access UserDefaults suite` - App Group not configured
- Empty data - Main app hasn't written to shared defaults yet

---

## 🔍 How to View Logs

### **Option 1: Xcode Console (During Development)**

1. Run your app in Xcode
2. Open the **Console** pane (bottom right)
3. Use filters:

```
// All CarpeCarb logs
subsystem:com.carpecarb

// Specific category
category:CloudSyncChannel

// Specific emoji
🔔

// Errors only
type:error

// Combine filters
category:CloudSyncStore AND type:error
```

### **Option 2: Console.app (Post-Installation)**

1. Open **Console.app** (in `/Applications/Utilities/`)
2. Select your iOS device or simulator
3. In the search field:

```
subsystem:com.carpecarb

// Or specific category
subsystem:com.carpecarb category:CloudSyncChannel
```

4. Click **Start** to stream logs

### **Option 3: Command Line**

```bash
# Stream logs from connected device
xcrun simctl spawn booted log stream --predicate 'subsystem == "com.carpecarb"'

# Or for physical device (requires device name)
log stream --device "iPhone" --predicate 'subsystem == "com.carpecarb"'

# Save to file
log stream --predicate 'subsystem == "com.carpecarb"' > carpecarb.log
```

---

## 🐛 Common Debugging Scenarios

### **Scenario 1: iCloud Sync Not Working**

**Check logs for:**
```
Filter: category:CloudSyncChannel OR category:CloudSyncStore
```

**Look for:**
- `iCloud availability: false` → User not signed into iCloud
- `❌ Failed to get plugin registrar` → CloudSyncChannel not registered
- `⚠️ Push aborted: iCloud not available` → iCloud disabled
- `Quota violation!` → Data exceeds 1MB limit

**Solution:**
1. Check Settings → [Name] → iCloud (signed in?)
2. Verify iCloud Drive is enabled
3. Check project capabilities (iCloud enabled?)
4. Verify entitlements include `com.apple.developer.ubiquity-kvstore-identifier`

---

### **Scenario 2: Widget Not Updating**

**Check logs for:**
```
Filter: category:CarbWiseWidget
```

**Look for:**
- `❌ Failed to access UserDefaults suite` → App Group misconfigured
- `Total carbs: 0.0g` → No data written yet
- `(no goal set)` → User hasn't set goal in main app

**Solution:**
1. Verify App Group ID matches: `group.com.jamesaguero.mycarbtracker`
2. Check that main app writes to UserDefaults with same suite name
3. Verify widget target has App Group capability
4. Force widget refresh: Long-press widget → Edit Widget

---

### **Scenario 3: Remote Changes Not Detected**

**Check logs for:**
```
Filter: 🔔 OR "remote change"
```

**Look for:**
- `⚠️ startObserving: Already observing` → Already observing (OK)
- `Timestamp unchanged - skipping notification` → No actual changes
- `External change notification received` but no callback → Check Flutter listener

**Solution:**
1. Verify `startObserving` was called
2. Check that other device is actually syncing
3. Wait a few seconds for iCloud propagation
4. Check Console for "Change reason" logs

---

### **Scenario 4: App Crashes on Background**

**Check logs for:**
```
Filter: ⏸️ OR 🛑
```

**Look for:**
- `Application entered background`
- Any `❌` errors around that time
- `CloudSyncChannel deallocated while still observing` → Potential issue

**Solution:**
1. Ensure proper cleanup in `applicationWillTerminate`
2. Check for retain cycles
3. Verify CloudSyncStore's `deinit` is called

---

## 📈 Log Levels Explained

### **debug**
- Internal state changes
- Method call details
- Data structure information
- Use for development only

### **info**
- Normal operations
- Method calls
- Successful operations
- User-facing events
- Safe for production

### **warning**
- Recoverable issues
- Unexpected but handled situations
- Configuration problems
- Should investigate but won't crash

### **error**
- Failures
- Invalid state
- Operations that should succeed but didn't
- Immediate attention required

---

## 🎯 Log Best Practices

### **1. Filter Effectively**

```
// Start broad
subsystem:com.carpecarb

// Narrow down
category:CloudSyncChannel

// Find specific issue
category:CloudSyncChannel AND type:error

// Track specific operation
⬆️ OR ⬇️
```

### **2. Correlation**

Look for patterns:
```
📞 Method call received: 'pushToCloud'
⬆️  pushToCloud: Pushing 3 key(s)
✓ pushToCloud: Completed
```

If you see the first two but not the third → operation failed.

### **3. Timeline Analysis**

Look at timestamps:
```
15:30:00 - pushToCloud started
15:30:00 - Successfully pushed to iCloud
15:30:02 - External change notification received
15:30:02 - Successfully pulled from iCloud
15:30:02 - Notifying of remote change
```

Shows 2-second sync latency (normal for iCloud).

### **4. Check All Layers**

When debugging sync issues, check all 3:
1. **AppDelegate** - Is CloudSyncChannel registered?
2. **CloudSyncChannel** - Is method being called from Flutter?
3. **CloudSyncStore** - Is iCloud available and syncing?

---

## 🔧 Adding Custom Logs

If you need to add more logging:

```swift
import os.log

// In your class
private let logger = Logger(subsystem: "com.carpecarb", category: "YourCategory")

// Logging
logger.debug("🔍 Detailed debug info")
logger.info("ℹ️ Something happened")
logger.warning("⚠️ Unexpected situation")
logger.error("❌ Something failed: \(error.localizedDescription)")

// With privacy
logger.info("User ID: \(userId, privacy: .private)")
logger.info("Public info: \(count, privacy: .public)")
```

---

## 📊 Performance Logging

To measure performance:

```swift
let start = Date()
// ... operation ...
let duration = Date().timeIntervalSince(start)
logger.debug("⏱️ Operation took \(String(format: "%.2f", duration))s")
```

Example in CloudSyncStore:
```swift
let start = Date()
kvStore.synchronize()
let duration = Date().timeIntervalSince(start)
logger.debug("⏱️ iCloud sync took \(String(format: "%.3f", duration))s")
```

---

## ✅ Summary

| Component | Logs | Filter |
|-----------|------|--------|
| **AppDelegate** | Lifecycle, initialization | `category:AppDelegate` |
| **CloudSyncChannel** | Method calls, Flutter bridge | `category:CloudSyncChannel` |
| **CloudSyncStore** | iCloud sync operations | `category:CloudSyncStore` |
| **CarbWiseWidget** | Widget data & timeline | `category:CarbWiseWidget` |

**All logs:** `subsystem:com.carpecarb`

The logging system is now production-ready and will help you:
- ✅ Debug issues faster
- ✅ Understand app behavior
- ✅ Track iCloud sync status
- ✅ Monitor widget updates
- ✅ Identify performance bottlenecks

Happy debugging! 🐛🔍
