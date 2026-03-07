/// Constantes generales de la aplicación
class AppConstants {
  AppConstants._();

  // API
  static const String apiBaseUrlDefineKey = 'API_BASE_URL';
  static const String defaultBaseUrl = 'http://192.168.1.14:3000/api/v1';
  static final String baseUrl = resolveBaseUrl();

  static String resolveBaseUrl({String? override}) {
    final candidate = (override ??
            const String.fromEnvironment(
              apiBaseUrlDefineKey,
              defaultValue: defaultBaseUrl,
            ))
        .trim();

    return candidate.isEmpty ? defaultBaseUrl : candidate;
  }

  // Timeouts (en segundos)
  static const int connectTimeout = 30;
  static const int receiveTimeout = 30;
  static const int sendTimeout = 30;

  // Almacenamiento local
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'auth_refresh_token';
  static const String expiresAtKey = 'auth_expires_at';
  static const String tokenTypeKey = 'auth_token_type';
  static const String userKey = 'user_data';
  static const String themeKey = 'app_theme';
  static const String localeKey = 'app_locale';

  // Dimensiones
  static const double paddingXS = 4.0;
  static const double paddingS = 8.0;
  static const double paddingM = 16.0;
  static const double paddingL = 24.0;
  static const double paddingXL = 32.0;

  // URLs
  static const String privacyPolicyUrl = 'https://sacdia.com/privacy';
  static const String termsUrl = 'https://sacdia.com/terms';
  static const String supportUrl = 'https://sacdia.com/support';
}
