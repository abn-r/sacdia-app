/// Constantes para la integración del mapa (flutter_map + CartoDB tiles).
///
/// ─────────────────────────────────────────────────────────────────
/// No se requiere API Key para el mapa — se usan tiles de CartoDB (Voyager).
/// El geocoding usa los geocoders nativos del dispositivo:
///   - iOS: CLGeocoder (Apple)
///   - Android: Android Geocoder (Google Play Services)
/// ─────────────────────────────────────────────────────────────────
class MapsConstants {
  MapsConstants._();

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
