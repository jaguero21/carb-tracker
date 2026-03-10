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
            // Flutter passes the full data payload as the call arguments
            let data = call.arguments as? [String: Any] ?? [:]
            syncStore.pushToCloud(data)
            result(true)

        case "pullFromCloud":
            let pulled = syncStore.pullFromCloud()
            result(pulled)

        case "startObserving":
            syncStore.startObserving { [weak self] data in
                DispatchQueue.main.async {
                    // Send the pulled data directly so Flutter can apply it
                    // without a separate round-trip pull call.
                    self?.channel.invokeMethod("onRemoteChange", arguments: data)
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
