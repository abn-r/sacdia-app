/// Constantes para la integración del mapa (google_maps_flutter).
///
/// ─────────────────────────────────────────────────────────────────
/// Se usa Google Maps (google_maps_flutter). Requiere API Key configurada
/// en AndroidManifest.xml y AppDelegate.swift.
/// El geocoding usa los geocoders nativos del dispositivo:
///   - iOS: CLGeocoder (Apple)
///   - Android: Android Geocoder (Google Play Services)
///
/// SECURITY: La API key NO se hardcodea en el código fuente.
/// Proveer mediante build config:
///   Android: gradle.properties → GOOGLE_MAPS_API_KEY=YOUR_KEY
///   iOS:     Xcode build settings → GOOGLE_MAPS_API_KEY=YOUR_KEY
///   CI:      Variable de entorno GOOGLE_MAPS_API_KEY en el runner.
/// ─────────────────────────────────────────────────────────────────
class MapsConstants {
  MapsConstants._();

  /// Google Maps API key, injected at compile-time via:
  ///   `--dart-define=GOOGLE_MAPS_API_KEY=<key>`
  ///
  /// For the Interactive Maps SDK (android/iOS) the key is configured
  /// natively via gradle.properties / Xcode build settings. This Dart
  /// constant is used ONLY for the Static Maps REST API (image tiles).
  ///
  /// If the key is empty the static map URL will 403 and the cached_network_image
  /// errorWidget is shown — a graceful degradation with no crash.
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  /// Ubicación por defecto cuando no hay ubicación del dispositivo disponible.
  /// Centro de México (Ciudad de México).
  static const double defaultLat = 19.4326;
  static const double defaultLong = -99.1332;

  /// Zoom por defecto al abrir el mapa.
  static const double defaultZoom = 14.0;

  /// Zoom al confirmar una búsqueda de lugar.
  static const double searchResultZoom = 16.0;

  /// Tile URL para CartoDB Voyager (retina) — estilo similar a Google Maps.
  /// Gratuito, sin API key, con soporte @2x para pantallas de alta densidad.
  static const String tileUrlTemplate =
      'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';

  /// Zoom nativo máximo soportado por los tiles.
  static const int maxNativeZoom = 19;

  /// Zoom máximo permitido (overscale más allá del nativo).
  static const double maxZoom = 22;

  /// User agent para las requests de tiles.
  static const String userAgent = 'com.sacdia.app';
}
