# CloudSyncChannel Error Handling Guide

## Overview

The CloudSyncChannel now includes comprehensive error handling for all iCloud sync operations. This document explains the error codes and how to handle them in your Flutter/Dart code.

## Error Codes

### `CLOUD_UNAVAILABLE`
**When:** iCloud is not available (user not signed in or iCloud disabled)

**Methods:** `pushToCloud`, `startObserving`

**Flutter Example:**
```dart
try {
  await cloudSync.pushToCloud(data);
} on PlatformException catch (e) {
  if (e.code == 'CLOUD_UNAVAILABLE') {
    // Show user-friendly message
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('iCloud Not Available'),
        content: Text('Please sign in to iCloud in Settings to sync your data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
}
```

---

### `INVALID_ARGUMENTS`
**When:** Method called with wrong argument types

**Methods:** `pushToCloud`

**Flutter Example:**
```dart
try {
  // This would fail - wrong type
  await cloudSync.pushToCloud("not a map");
} on PlatformException catch (e) {
  if (e.code == 'INVALID_ARGUMENTS') {
    print('Error: ${e.message}');
    print('Details: ${e.details}');
  }
}
```

---

### `DATA_TOO_LARGE`
**When:** Data exceeds iCloud KV Store limits (1MB total or 1KB per key)

**Methods:** `pushToCloud`

**Flutter Example:**
```dart
try {
  await cloudSync.pushToCloud(massiveData);
} on PlatformException catch (e) {
  if (e.code == 'DATA_TOO_LARGE') {
    // Reduce data size or split into smaller chunks
    print('Data too large for iCloud: ${e.message}');
    
    // Option 1: Remove non-essential data
    final essentialData = filterEssentialData(massiveData);
    await cloudSync.pushToCloud(essentialData);
    
    // Option 2: Show error to user
    showSnackBar('Too much data to sync. Please reduce saved items.');
  }
}
```

---

### `INVALID_DATA`
**When:** Attempting to push empty data

**Methods:** `pushToCloud`

**Flutter Example:**
```dart
final data = await getDataToSync();

if (data.isEmpty) {
  // Handle locally - don't try to push
  print('No data to sync');
} else {
  try {
    await cloudSync.pushToCloud(data);
  } catch (e) {
    print('Sync failed: $e');
  }
}
```

---

## Complete Flutter Integration Example

```dart
class CloudSyncService {
  static const _channel = MethodChannel('com.carpecarb/cloudsync');
  
  // Check if iCloud is available
  Future<bool> isAvailable() async {
    try {
      final available = await _channel.invokeMethod<bool>('isAvailable');
      return available ?? false;
    } catch (e) {
      print('Error checking iCloud availability: $e');
      return false;
    }
  }
  
  // Push data to iCloud with error handling
  Future<bool> pushToCloud(Map<String, dynamic> data) async {
    try {
      await _channel.invokeMethod('pushToCloud', data);
      return true;
    } on PlatformException catch (e) {
      _handlePushError(e);
      return false;
    }
  }
  
  // Pull data from iCloud
  Future<Map<String, dynamic>?> pullFromCloud() async {
    try {
      final result = await _channel.invokeMethod('pullFromCloud');
      return result != null ? Map<String, dynamic>.from(result) : null;
    } catch (e) {
      print('Error pulling from iCloud: $e');
      return null;
    }
  }
  
  // Start observing remote changes
  Future<void> startObserving(Function(Map<String, dynamic>) onRemoteChange) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onRemoteChange') {
        final data = Map<String, dynamic>.from(call.arguments);
        onRemoteChange(data);
      }
    });
    
    try {
      await _channel.invokeMethod('startObserving');
    } on PlatformException catch (e) {
      if (e.code == 'CLOUD_UNAVAILABLE') {
        print('Cannot observe: iCloud not available');
      }
    }
  }
  
  // Stop observing
  Future<void> stopObserving() async {
    try {
      await _channel.invokeMethod('stopObserving');
    } catch (e) {
      print('Error stopping observation: $e');
    }
  }
  
  // Private error handler
  void _handlePushError(PlatformException e) {
    switch (e.code) {
      case 'CLOUD_UNAVAILABLE':
        print('⚠️ iCloud not available: ${e.message}');
        // Show user a message to sign in to iCloud
        break;
        
      case 'DATA_TOO_LARGE':
        print('❌ Data too large: ${e.message}');
        // Reduce data size or notify user
        break;
        
      case 'INVALID_DATA':
        print('❌ Invalid data: ${e.message}');
        // Log and fix data validation
        break;
        
      case 'INVALID_ARGUMENTS':
        print('❌ Invalid arguments: ${e.message}');
        // This is a developer error - fix the call
        break;
        
      default:
        print('❌ Unknown error: ${e.code} - ${e.message}');
    }
  }
}
```

---

## Data Size Limits

### NSUbiquitousKeyValueStore Limits

| Limit | Value |
|-------|-------|
| **Total storage** | 1 MB |
| **Maximum keys** | 1024 |
| **Per-key size** | ~1 KB (recommended) |

### Best Practices

1. **Keep data minimal**
   ```dart
   // ❌ Don't store entire objects
   final data = {
     'food_items': allFoodItems.map((f) => f.toJson()).toList(),
   };
   
   // ✅ Store only IDs or essential data
   final data = {
     'food_item_ids': allFoodItems.map((f) => f.id).toList(),
     'daily_carb_goal': carbGoal,
   };
   ```

2. **Validate before pushing**
   ```dart
   Future<void> syncToCloud(Map<String, dynamic> data) async {
     final jsonString = jsonEncode(data);
     final sizeInBytes = utf8.encode(jsonString).length;
     
     if (sizeInBytes > 900000) { // 900KB safety margin
       print('Warning: Data approaching size limit');
       // Trim or compress data
     }
     
     await cloudSync.pushToCloud(data);
   }
   ```

3. **Handle failures gracefully**
   ```dart
   try {
     await cloudSync.pushToCloud(data);
   } catch (e) {
     // Don't block user - queue for retry
     await _queueForRetry(data);
   }
   ```

---

## Logging

The native side now includes comprehensive logging using `os.log`. To view logs:

### Xcode Console
```
🔍 Filter: "CloudSync"
```

### Console.app (macOS)
```
1. Open Console.app
2. Select your device
3. Filter: process:Runner category:CloudSync
```

### Log Levels

| Level | When |
|-------|------|
| **info** | Successful operations |
| **debug** | Method calls and flow |
| **warning** | Recoverable issues (iCloud unavailable, etc.) |
| **error** | Actual failures that need attention |

---

## Testing Error Scenarios

### Test iCloud Unavailable
```dart
test('handles iCloud unavailable gracefully', () async {
  // Sign out of iCloud on test device
  final result = await cloudSync.pushToCloud({'test': 'data'});
  expect(result, false); // Should fail gracefully
});
```

### Test Data Too Large
```dart
test('handles oversized data', () async {
  final largeData = {
    'huge_array': List.generate(100000, (i) => 'item$i'),
  };
  
  expect(
    () => cloudSync.pushToCloud(largeData),
    throwsA(isA<PlatformException>()
      .having((e) => e.code, 'code', 'DATA_TOO_LARGE')),
  );
});
```

---

## Migration Guide

If you have existing code, update it to handle errors:

### Before
```dart
// Silent failures - bad!
await methodChannel.invokeMethod('pushToCloud', data);
```

### After
```dart
// Explicit error handling - good!
try {
  await methodChannel.invokeMethod('pushToCloud', data);
  print('✅ Synced to iCloud');
} on PlatformException catch (e) {
  print('❌ Sync failed: ${e.code} - ${e.message}');
  // Handle appropriately
}
```

---

## Summary

✅ **All methods now have proper error handling**  
✅ **Descriptive error codes for Flutter**  
✅ **Data size validation prevents silent failures**  
✅ **Comprehensive logging for debugging**  
✅ **Graceful degradation when iCloud unavailable**  

The improved error handling ensures your app:
- Never crashes due to sync issues
- Provides clear feedback to users
- Helps developers debug problems
- Handles edge cases gracefully
