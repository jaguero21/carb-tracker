import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class CloudSyncService {
  static const _channel = MethodChannel('com.carpecarb/cloudsync');
  static const _remoteChangeDebounce = Duration(milliseconds: 300);

  VoidCallback? _onRemoteChange;
  Timer? _remoteChangeDebounceTimer;

  CloudSyncService() {
    _channel.setMethodCallHandler(_handleMethod);
  }

  Future<dynamic> _handleMethod(MethodCall call) async {
    if (call.method == 'onRemoteChange') {
      _remoteChangeDebounceTimer?.cancel();
      _remoteChangeDebounceTimer = Timer(_remoteChangeDebounce, () {
        _onRemoteChange?.call();
      });
    }
  }

  Future<bool> isAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAvailable');
      return result ?? false;
    } catch (e) {
      debugPrint('CloudSyncService.isAvailable error: $e');
      return false;
    }
  }

  Future<void> pushToCloud() async {
    try {
      await _channel.invokeMethod('pushToCloud');
    } catch (e) {
      debugPrint('CloudSyncService.pushToCloud error: $e');
    }
  }

  Future<Map<String, dynamic>?> pullFromCloud() async {
    try {
      final result = await _channel.invokeMethod<Map>('pullFromCloud');
      return result?.cast<String, dynamic>();
    } catch (e) {
      debugPrint('CloudSyncService.pullFromCloud error: $e');
      return null;
    }
  }

  Future<void> startListening(VoidCallback onRemoteChange) async {
    _onRemoteChange = onRemoteChange;
    try {
      await _channel.invokeMethod('startObserving');
    } catch (e) {
      debugPrint('CloudSyncService.startListening error: $e');
    }
  }

  Future<void> stopListening() async {
    _onRemoteChange = null;
    _remoteChangeDebounceTimer?.cancel();
    _remoteChangeDebounceTimer = null;
    try {
      await _channel.invokeMethod('stopObserving');
    } catch (e) {
      debugPrint('CloudSyncService.stopListening error: $e');
    }
  }
}
