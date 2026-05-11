import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // GOOGLE_MAPS_API_KEY must be set in Xcode build settings or via xcconfig.
    // Never hardcode the key here — use the Info.plist placeholder $(GOOGLE_MAPS_API_KEY).
    guard let mapsKey = Bundle.main.infoDictionary?["GOOGLE_MAPS_API_KEY"] as? String,
          !mapsKey.isEmpty else {
      assertionFailure("GOOGLE_MAPS_API_KEY is missing from Info.plist. Set it in Xcode build settings or via xcconfig.")
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    GMSServices.provideAPIKey(mapsKey)

    // Forzar renderer OpenGL en simuladores — Metal no renderiza en iOS Simulator
    #if targetEnvironment(simulator)
    GMSServices.setMetalRendererEnabled(false)
    #endif

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
