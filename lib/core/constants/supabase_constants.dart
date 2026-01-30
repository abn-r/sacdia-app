/// Constantes para la configuración de Supabase
class SupabaseConstants {
  SupabaseConstants._();
  
  // Configuración principal
  static const String url = 'https://pfjdavhuriyhtqyifwky.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBmamRhdmh1cml5aHRxeWlmd2t5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MDg2MjY0MDAsImV4cCI6MjAyNDIwMjQwMH0.OlIfWioRlPSdK_h_CAEB0WPzBKyXl6GrfVaShPHB-NM';
  
  // Nombres de tablas
  static const String usersTable = 'users';
  static const String profilesTable = 'profiles';
  static const String settingsTable = 'user_settings';
  
  // Valores predeterminados
  static const int defaultSessionExpiry = 60 * 60 * 24 * 7; // 7 días
}
