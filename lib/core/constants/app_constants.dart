import 'package:flutter/foundation.dart';

/// Constantes generales de la aplicación
class AppConstants {
  AppConstants._();

  // API
  static const String apiBaseUrlDefineKey = 'API_BASE_URL';
  // Local dev: --dart-define=API_BASE_URL=http://localhost:3000/api/v1
  //static const String defaultBaseUrl = 'https://sacdia-backend.onrender.com/api/v1';
  static const String defaultBaseUrl = 'http://localhost:3000/api/v1';

  static final String baseUrl = resolveBaseUrl();

  static String resolveBaseUrl({String? override}) {
    final candidate = (override ??
            const String.fromEnvironment(
              apiBaseUrlDefineKey,
              defaultValue: defaultBaseUrl,
            ))
        .trim();

    final resolvedUrl = candidate.isEmpty ? defaultBaseUrl : candidate;
    if (kReleaseMode && !resolvedUrl.startsWith('https://')) {
      throw StateError('Production builds must use HTTPS');
    }
    return resolvedUrl;
  }

  // Timeouts (en segundos)
  static const int connectTimeout = 10;
  static const int receiveTimeout = 15;
  static const int sendTimeout = 15;

  // Almacenamiento local
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'auth_refresh_token';
  static const String expiresAtKey = 'auth_expires_at';
  static const String tokenTypeKey = 'auth_token_type';
  static const String userKey = 'user_data';
  static const String themeKey = 'app_theme';
  static const String localeKey = 'app_locale';

  // Caché de PII de usuario (SecureStorage)
  static const String cachedUserId = 'cached_user_id';
  static const String cachedUserEmail = 'cached_user_email';
  static const String cachedUserName = 'cached_user_name';
  static const String cachedUserAvatar = 'cached_user_avatar';

  // Caché del grant activo (SecureStorage) — elimina la race condition en cold start
  static const String cachedActiveAssignmentId = 'cached_active_assignment_id';
  static const String cachedActiveRoleName = 'cached_active_role_name';
  static const String cachedActiveClubName = 'cached_active_club_name';
  static const String cachedActiveClubType = 'cached_active_club_type';

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
