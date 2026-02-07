/// Constantes generales de la aplicación
class AppConstants {
  AppConstants._();
  
  // API
  //static const String baseUrl = 'https://api.sacdia.com/v1';
  static const String baseUrl = 'http://127.0.0.1:3000/api/v1';
  //static const String apiUrl = 'http://127.0.0.1:3000';
  
  // Timeouts (en segundos)
  static const int connectTimeout = 30;
  static const int receiveTimeout = 30;
  static const int sendTimeout = 30;
  
  // Almacenamiento local
  static const String tokenKey = 'auth_token';
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
