import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyAQoO0HmAfSdbRs-T0cqtCXEGNn7TtMGZk")

    // Forzar renderer OpenGL en simuladores — Metal no renderiza en iOS Simulator
    #if targetEnvironment(simulator)
    GMSServices.setMetalRendererEnabled(false)
    #endif

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
