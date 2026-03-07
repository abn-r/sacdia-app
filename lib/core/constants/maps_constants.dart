/// Constantes para la integración del mapa (flutter_map + OpenStreetMap).
///
/// ─────────────────────────────────────────────────────────────────
/// No se requiere API Key para el mapa — se usan tiles de OpenStreetMap.
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
}
