/// Resultado de búsqueda de ubicación devuelto por Nominatim.
class LocationSearchResult {
  final double lat;
  final double lon;
  final String displayName;

  const LocationSearchResult({
    required this.lat,
    required this.lon,
    required this.displayName,
  });
}
