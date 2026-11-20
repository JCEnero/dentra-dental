import Flutter
import GoogleMaps
import NetworkExtension
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let setupPrefix = "Dentra Cam "
  private var setupSSID: String?
  private var wifiJoinResult: FlutterResult?
  private var wifiJoinTimeout: DispatchWorkItem?
  private var wifiJoinGeneration = 0
  private var wifiSetupWanted = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // The Maps SDK needs its key before any map is created.
    if let key = Self.mapsApiKey() {
      GMSServices.provideAPIKey(key)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "com.dentra/wifi_setup",
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      switch call.method {
      case "join":
        let args = call.arguments as? [String: Any]
        guard let key = args?["password"] as? String,
              key.range(of: "^[A-Za-z0-9]{16}$", options: .regularExpression) != nil else {
          result(FlutterError(code: "bad_key", message: "Enter the device setup key.", details: nil))
          return
        }
        self.joinSetupNetwork(key: key, result: result)
      case "rememberDevice":
        let args = call.arguments as? [String: Any]
        if let ssid = args?["ssid"] as? String, ssid.hasPrefix(self.setupPrefix) {
          self.setupSSID = ssid
        }
        result(nil)
      case "leave":
        self.wifiSetupWanted = false
        self.wifiJoinGeneration += 1
        self.finishWifiJoin(error: "cancelled")
        self.removeSetupNetwork()
        result(nil)
      case "discover":
        // In account mode, verification uses the cloud relay. Local setup
        // first verifies the DHCP address returned by /setup/status.
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  private func joinSetupNetwork(key: String, result: @escaping FlutterResult) {
    guard wifiJoinResult == nil else {
      result(FlutterError(code: "busy", message: "A connection is already in progress.", details: nil))
      return
    }
    wifiJoinGeneration += 1
    let generation = wifiJoinGeneration
    wifiJoinResult = result
    wifiSetupWanted = true
    let config = NEHotspotConfiguration(ssidPrefix: setupPrefix, passphrase: key, isWEP: false)
    config.joinOnce = true
    let timeout = DispatchWorkItem { [weak self] in
      guard let self = self, self.wifiJoinGeneration == generation else { return }
      self.wifiSetupWanted = false
      self.wifiJoinGeneration += 1
      self.finishWifiJoin(error: "unavailable")
      self.removeSetupNetwork()
    }
    wifiJoinTimeout = timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + 65, execute: timeout)
    NEHotspotConfigurationManager.shared.apply(config) { [weak self] error in
      DispatchQueue.main.async {
        guard let self = self else { return }
        guard self.wifiJoinGeneration == generation else {
          if !self.wifiSetupWanted { self.removeSetupNetwork() }
          return
        }
        if let failure = error as NSError? {
          if failure.domain == NEHotspotConfigurationErrorDomain &&
              failure.code == NEHotspotConfigurationError.alreadyAssociated.rawValue {
            self.finishWifiJoin(error: nil)
          } else {
            let cancelled = failure.domain == NEHotspotConfigurationErrorDomain &&
                failure.code == NEHotspotConfigurationError.userDenied.rawValue
            self.finishWifiJoin(error: cancelled ? "cancelled" : "unavailable")
          }
        } else {
          // Dart confirms actual reachability; approval alone is not success.
          self.finishWifiJoin(error: nil)
        }
      }
    }
  }

  private func finishWifiJoin(error: String?) {
    wifiJoinTimeout?.cancel()
    wifiJoinTimeout = nil
    guard let result = wifiJoinResult else { return }
    wifiJoinResult = nil
    if let error = error {
      result(FlutterError(code: error, message: "Wi-Fi connection did not complete.", details: nil))
    } else { result(nil) }
  }

  private func removeSetupNetwork() {
    if let ssid = setupSSID {
      NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: ssid)
    }
    NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: setupPrefix)
    setupSSID = nil
  }

  /// Reads MAPS_API_KEY from the bundled `.env` Flutter asset, the same
  /// file web and Android use, so the key lives in one place.
  private static func mapsApiKey() -> String? {
    let assetKey = FlutterDartProject.lookupKey(forAsset: ".env")
    guard let path = Bundle.main.path(forResource: assetKey, ofType: nil),
          let contents = try? String(contentsOfFile: path, encoding: .utf8)
    else { return nil }

    for line in contents.split(whereSeparator: \.isNewline) {
      let parts = line.split(separator: "=", maxSplits: 1)
      guard parts.count == 2,
            parts[0].trimmingCharacters(in: .whitespaces) == "MAPS_API_KEY"
      else { continue }
      let value = parts[1]
        .trimmingCharacters(in: .whitespaces)
        .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
      return value.isEmpty ? nil : value
    }
    return nil
  }
}
