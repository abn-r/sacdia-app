/// Esquema que el widget usa para abrir la app.
///
/// El query `homeWidget` hace que el plugin de iOS entregue el toque a Flutter
/// en lugar de tratarlo como un deep link de OAuth.
const String nextActivityWidgetScheme = 'io.sacdia.app';

Uri nextActivityWidgetLaunchUri(int activityId) {
  return Uri(
    scheme: nextActivityWidgetScheme,
    host: 'activity',
    path: '/$activityId',
    queryParameters: const {'homeWidget': ''},
  );
}

int? activityIdFromWidgetUri(Uri? uri) {
  if (uri == null) return null;
  if (uri.scheme != nextActivityWidgetScheme) return null;
  if (uri.host != 'activity') return null;

  for (final segment in uri.pathSegments) {
    final id = int.tryParse(segment);
    if (id != null && id > 0) return id;
  }
  return null;
}
