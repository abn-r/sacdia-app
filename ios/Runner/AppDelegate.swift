import Flutter
import UIKit
import GoogleMaps // Requerido por google_maps_flutter

// TODO: Activa "Maps SDK for iOS" y "Geocoding API" en Google Cloud Console
//       para la misma API Key que usas en Android.
//       Reemplaza "TU_GOOGLE_MAPS_API_KEY_AQUI" con tu clave real.

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyCg2AIgPaE1rsCdmzNnAWPYmtVQ0jQu6oY")
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
