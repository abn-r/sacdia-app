/// Constantes para la integración del mapa (google_maps_flutter).
///
/// ─────────────────────────────────────────────────────────────────
/// Se usa Google Maps (google_maps_flutter). Requiere API Key configurada
/// en AndroidManifest.xml y AppDelegate.swift.
/// El geocoding usa los geocoders nativos del dispositivo:
///   - iOS: CLGeocoder (Apple)
///   - Android: Android Geocoder (Google Play Services)
/// ─────────────────────────────────────────────────────────────────
class MapsConstants {
  MapsConstants._();

  /// Google Maps API key — used for Static Maps API image requests.
  ///
  /// The same key is configured in:
  ///   - ios/Runner/AppDelegate.swift  (GMSServices.provideAPIKey)
  ///   - android/app/src/main/AndroidManifest.xml  (com.google.android.geo.API_KEY)
  ///
  /// TODO: Move to --dart-define=GOOGLE_MAPS_API_KEY to avoid committing the key.
  static const String googleMapsApiKey = 'AIzaSyAQoO0HmAfSdbRs-T0cqtCXEGNn7TtMGZk';

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
