import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/services.dart';

class CloudSyncService {
  static const _channel = MethodChannel('com.carpecarb/cloudsync');
  static const _remoteChangeDebounce = Duration(milliseconds: 300);

  void Function(Map<String, dynamic>?)? _onRemoteChange;
  Timer? _remoteChangeDebounceTimer;

  CloudSyncService() {
    _channel.setMethodCallHandler(_handleMethod);
  }

  Future<dynamic> _handleMethod(MethodCall call) async {
    if (call.method == 'onRemoteChange') {
      final data = (call.arguments as Map?)?.cast<String, dynamic>();
      _remoteChangeDebounceTimer?.cancel();
      _remoteChangeDebounceTimer = Timer(_remoteChangeDebounce, () {
        _onRemoteChange?.call(data);
      });
    }
  }

  Future<bool> isAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAvailable');
      return result ?? false;
    } catch (e) {
      dev.log('CloudSyncService.isAvailable error: $e');
      return false;
    }
  }

  /// Push [data] to iCloud. Flutter is responsible for passing all syncable keys.
  Future<void> pushToCloud(Map<String, dynamic> data) async {
    try {
      await _channel.invokeMethod('pushToCloud', data);
    } catch (e) {
      dev.log('CloudSyncService.pushToCloud error: $e');
    }
  }

  /// Pull data from iCloud. Returns the full payload (including cloud_last_modified)
  /// or null if iCloud is unavailable or has no data yet.
  Future<Map<String, dynamic>?> pullFromCloud() async {
    try {
      final result = await _channel.invokeMethod<Map>('pullFromCloud');
      return result?.cast<String, dynamic>();
    } catch (e) {
      dev.log('CloudSyncService.pullFromCloud error: $e');
      return null;
    }
  }

  /// Start listening for remote changes. [onRemoteChange] is called with the
  /// pulled data whenever another device pushes an update.
  Future<void> startListening(
      void Function(Map<String, dynamic>?) onRemoteChange) async {
    _onRemoteChange = onRemoteChange;
    try {
      await _channel.invokeMethod('startObserving');
    } catch (e) {
      dev.log('CloudSyncService.startListening error: $e');
    }
  }

  Future<void> stopListening() async {
    _onRemoteChange = null;
    _remoteChangeDebounceTimer?.cancel();
    _remoteChangeDebounceTimer = null;
    try {
      await _channel.invokeMethod('stopObserving');
    } catch (e) {
      dev.log('CloudSyncService.stopListening error: $e');
    }
  }
}
