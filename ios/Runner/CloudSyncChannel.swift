import Flutter
import CarbShared

/// Bridges Flutter ↔ CloudSyncStore via a MethodChannel.
class CloudSyncChannel {
    static let channelName = "com.carpecarb/cloudsync"

    private let channel: FlutterMethodChannel
    private let syncStore = CloudSyncStore.shared

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isAvailable":
            result(syncStore.isAvailable)

        case "pushToCloud":
            syncStore.pushToCloud()
            result(true)

        case "pullFromCloud":
            let pulled = syncStore.pullFromCloud()
            result(pulled)

        case "startObserving":
            syncStore.startObserving { [weak self] in
                DispatchQueue.main.async {
                    self?.channel.invokeMethod("onRemoteChange", arguments: nil)
                }
            }
            result(true)

        case "stopObserving":
            syncStore.stopObserving()
            result(true)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
