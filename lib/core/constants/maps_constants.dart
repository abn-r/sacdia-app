/// Constantes para la integración con Google Maps.
///
/// ─────────────────────────────────────────────────────────────────
/// CONFIGURACIÓN REQUERIDA ANTES DE USAR EL MAPA
/// ─────────────────────────────────────────────────────────────────
///
/// 1. Obtén una API Key en: https://console.cloud.google.com/
///    Activa los siguientes servicios para esa key:
///      - Maps SDK for Android
///      - Maps SDK for iOS
///      - Geocoding API
///
/// 2. ANDROID — agrega la key en:
///    android/app/src/main/AndroidManifest.xml
///    dentro de <application>:
///
///      <meta-data
///        android:name="com.google.android.geo.API_KEY"
///        android:value="TU_API_KEY_AQUI"/>
///
/// 3. iOS — inicializa la key en:
///    ios/Runner/AppDelegate.swift
///    agrega al principio:  import GoogleMaps
///    y dentro de application(_:didFinishLaunchingWithOptions:):
///      GMSServices.provideAPIKey("TU_API_KEY_AQUI")
///
/// 4. iOS — agrega en ios/Runner/Info.plist el permiso de localización:
///
///      <key>NSLocationWhenInUseUsageDescription</key>
///      <string>SACDIA necesita acceso a tu ubicación para seleccionar el lugar de la actividad.</string>
///
/// ─────────────────────────────────────────────────────────────────
/// NO HARDCODEES tu API Key en este archivo si el repositorio es
/// público. Usa flutter_dotenv o similar para leerla desde .env.
/// ─────────────────────────────────────────────────────────────────
class MapsConstants {
  MapsConstants._();

  /// API Key de Google Maps.
  ///
  /// Reemplaza este valor con tu clave real, o mejor aún, cárgala
  /// desde una variable de entorno usando flutter_dotenv:
  ///   static final String googleMapsApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  // TODO: Reemplaza con tu API Key de Google Maps antes de compilar.
  static const String googleMapsApiKey = 'AIzaSyCg2AIgPaE1rsCdmzNnAWPYmtVQ0jQu6oY';//'TU_GOOGLE_MAPS_API_KEY_AQUI';

  /// Ubicación por defecto cuando no hay ubicación del dispositivo disponible.
  /// Centro de México (Ciudad de México).
  static const double defaultLat = 19.4326;
  static const double defaultLong = -99.1332;

  /// Zoom por defecto al abrir el mapa.
  static const double defaultZoom = 14.0;

  /// Zoom al confirmar una búsqueda de lugar.
  static const double searchResultZoom = 16.0;
}
