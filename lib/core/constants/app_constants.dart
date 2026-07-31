/// Constantes generales de la aplicación
class AppConstants {
  AppConstants._();

  // API
  static const String apiBaseUrlDefineKey = 'API_BASE_URL';
  static const String releaseApiBaseUrlRequiredCode =
      'RELEASE_API_BASE_URL_REQUIRED';
  static const String releaseApiBaseUrlNotHttpsCode =
      'RELEASE_API_BASE_URL_NOT_HTTPS';

  static const String localDevelopmentBaseUrl = 'http://localhost:3000/api/v1';
  static const bool _isProduct = bool.fromEnvironment('dart.vm.product');
  static final String apiBaseUrl = resolveBaseUrl(
    override: const String.fromEnvironment(apiBaseUrlDefineKey),
    isProduct: _isProduct,
  );

  static String resolveBaseUrl({
    String? override,
    bool isProduct = _isProduct,
  }) {
    final candidate =
        override ?? const String.fromEnvironment(apiBaseUrlDefineKey);
    if (!isProduct) {
      return candidate.isEmpty ? localDevelopmentBaseUrl : candidate;
    }

    return validateReleaseBaseUrl(candidate);
  }

  /// Validates the only API origin accepted by a release artifact.
  ///
  /// The separate method keeps the release policy testable without making a
  /// test-only switch capable of weakening the runtime release decision.
  static String validateReleaseBaseUrl(String value) {
    if (value.isEmpty) {
      throw StateError(releaseApiBaseUrlRequiredCode);
    }

    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.isAbsolute ||
        uri.scheme != 'https' ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.authority.contains('@') ||
        uri.hasPort ||
        uri.hasFragment ||
        uri.hasQuery ||
        !_isAllowedReleaseDnsName(uri.host) ||
        value !=
            Uri(scheme: 'https', host: uri.host, path: '/api/v1').toString()) {
      throw StateError(releaseApiBaseUrlNotHttpsCode);
    }

    return value;
  }

  static bool _isAllowedReleaseDnsName(String host) {
    if (host.length > 253 ||
        host.endsWith('.') ||
        host == 'localhost' ||
        host.endsWith('.localhost') ||
        host.endsWith('.local')) {
      return false;
    }

    final labels = host.split('.');
    if (labels.length < 2) return false;

    final labelPattern = RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$');
    return labels.every(labelPattern.hasMatch) &&
        RegExp(r'^[a-z](?:[a-z0-9-]{0,61}[a-z0-9])?$').hasMatch(labels.last);
  }

  // Timeouts (en segundos)
  static const int connectTimeout = 10;
  static const int receiveTimeout = 15;
  static const int sendTimeout = 15;

  // Cache keys for SharedPreferences-backed local cache
  static const String catalogClubTypesCacheKey = 'catalog_club_types';
  static const String catalogActivityTypesCacheKey = 'catalog_activity_types';
  static const String catalogDistrictsCacheKey = 'catalog_districts';
  static const String catalogChurchesCacheKey = 'catalog_churches';
  static const String catalogEcclesiasticalYearsCacheKey =
      'catalog_ecclesiastical_years';
  static const String catalogCurrentEcclesiasticalYearCacheKey =
      'catalog_current_ecclesiastical_year';
  static const String dashboardSummaryCacheKeyPrefix = 'dashboard_summary';

  // Almacenamiento local
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'auth_refresh_token';
  static const String expiresAtKey = 'auth_expires_at';
  static const String tokenTypeKey = 'auth_token_type';
  static const String userKey = 'user_data';
  static const String themeKey = 'app_theme';
  static const String localeKey = 'app_locale';

  // Accessibility (MVP: SharedPreferences only)
  static const String accessibilityTextSizeKey = 'app_a11y_text_size';
  static const String accessibilityHighContrastKey = 'app_a11y_high_contrast';
  static const String accessibilityReduceMotionKey = 'app_a11y_reduce_motion';

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
  static const String cachedActivePermissions = 'cached_active_permissions';
  static const String cachedActiveClubId = 'cached_active_club_id';
  static const String cachedActiveSectionId = 'cached_active_section_id';
  static const String cachedActiveClubTypeId = 'cached_active_club_type_id';

  // Biometric auth (SharedPreferences)
  // MVP: opt-in only, boolean flag + ISO-8601 enrolledAt; no biometric data stored.
  static const String biometricEnabledKey = 'biometric_enabled';
  static const String biometricEnrolledAtKey = 'biometric_enrolled_at';

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
