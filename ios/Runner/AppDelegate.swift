import Flutter
import UIKit
import CarbShared

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var cloudSyncChannel: CloudSyncChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Register our custom method channel against the implicit engine messenger.
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "CloudSyncChannel") else {
      return
    }
    cloudSyncChannel = CloudSyncChannel(messenger: registrar.messenger())
  }
}
