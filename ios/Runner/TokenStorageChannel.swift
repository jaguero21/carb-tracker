import Flutter
import CarbShared
import os.log

/// Flutter MethodChannel bridge for secure token storage.
/// Writes the Firebase ID token to both Keychain (secure) and the App Group
/// UserDefaults (for extension backward compatibility) atomically.
///
/// Channel: com.carpecarb/tokenstorage
/// Methods:
///   saveToken(String) → void
///   clearToken()      → void
class TokenStorageChannel {
    static let channelName = "com.carpecarb/tokenstorage"
    private static let tokenKey = "firebaseIdToken"

    private let channel: FlutterMethodChannel
    private let logger = Logger(subsystem: "com.carpecarb", category: "TokenStorageChannel")

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "saveToken":
            guard let token = call.arguments as? String, !token.isEmpty else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "token must be a non-empty string", details: nil))
                return
            }
            // Write to Keychain (secure) and UserDefaults (backward compat for
            // extensions until Keychain Sharing capability is enabled for all targets).
            KeychainHelper.save(token, forKey: Self.tokenKey)
            UserDefaults(suiteName: CarbDataStore.appGroupID)?.set(token, forKey: Self.tokenKey)
            logger.debug("Firebase ID token saved to Keychain + UserDefaults")
            result(nil)

        case "clearToken":
            KeychainHelper.delete(forKey: Self.tokenKey)
            UserDefaults(suiteName: CarbDataStore.appGroupID)?.removeObject(forKey: Self.tokenKey)
            logger.debug("Firebase ID token cleared from Keychain + UserDefaults")
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
