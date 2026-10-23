// Overview: Registers Flutter plugins and streams foreground iOS location updates with permission handling.
import Flutter
import UIKit
import CoreLocation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let locationStream = VerdiLocationStream()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VerdiLocation") {
      FlutterEventChannel(name: "verdi/phone_location", binaryMessenger: registrar.messenger())
        .setStreamHandler(locationStream)
    }
  }
}


final class VerdiLocationStream: NSObject, FlutterStreamHandler, CLLocationManagerDelegate {
  private let manager = CLLocationManager()
  private var sink: FlutterEventSink?
  override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyBest
    manager.distanceFilter = kCLDistanceFilterNone
    NotificationCenter.default.addObserver(self, selector: #selector(backgrounded),
      name: UIApplication.didEnterBackgroundNotification, object: nil)
  }
  deinit { NotificationCenter.default.removeObserver(self); manager.stopUpdatingLocation() }
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
    else { updateAuthorization() }
    return nil
  }
  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    manager.stopUpdatingLocation(); sink = nil; return nil
  }
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { updateAuthorization() }
  private func updateAuthorization() {
    guard sink != nil else { return }
    switch manager.authorizationStatus {
    case .authorizedWhenInUse, .authorizedAlways:
      if manager.accuracyAuthorization != .fullAccuracy {
        fail("precision", "Enable Precise Location in Settings, then retry tracking.")
      } else { manager.startUpdatingLocation() }
    case .denied, .restricted: fail("permission", "Location access is denied. Enable it in Settings, then retry.")
    case .notDetermined: break
    @unknown default: fail("permission", "Location authorization is unavailable.")
    }
  }
  private func fail(_ code: String, _ message: String) {
    manager.stopUpdatingLocation()
    sink?(FlutterError(code: code, message: message, details: nil))
  }
  @objc private func backgrounded() { fail("paused", "App left the foreground. Re-enable tracking when you return.") }
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    for location in locations {
      guard location.horizontalAccuracy >= 0 else { continue }
      sink?(["latitude": location.coordinate.latitude, "longitude": location.coordinate.longitude,
        "accuracy": location.horizontalAccuracy, "timestamp": Int64(location.timestamp.timeIntervalSince1970 * 1000)])
    }
  }
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    if let code = (error as? CLError)?.code, code == .locationUnknown { return }
    fail("location", "Location became unavailable. Check permissions and services, then retry.")
  }
}
