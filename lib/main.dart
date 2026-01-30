import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/auth/supabase_auth.dart';
import 'core/storage/local_storage.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/presentation/widgets/auth_gate.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'providers/storage_provider.dart';

/// Punto de entrada principal de la aplicación
Future<void> main() async {
  // Aseguramos que las dependencias de Flutter estén inicializadas
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configuramos la orientación preferida de la aplicación
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Iniciamos Supabase
  await SupabaseAuth.initialize();
  
  // Verificar y limpiar posibles sesiones antiguas inválidas al iniciar
  await _checkAndCleanSessionAtStartup();
  
  // Inicializamos SharedPreferences para almacenamiento local
  final sharedPreferences = await SharedPreferences.getInstance();
  
  // Recuperar estado de cierre de sesión manual
  final wasManuallyLoggedOut = sharedPreferences.getBool('user_manually_logged_out') ?? false;
  
  // Ejecutamos la aplicación con la configuración inicial
  runApp(
    ProviderScope(
      overrides: [
        // Proporcionamos la instancia de SharedPreferences a la aplicación
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        // Restauramos el estado de cierre de sesión manual
        isUserLoggedOutProvider.overrideWith((ref) => wasManuallyLoggedOut),
      ],
      child: const MyApp(),
    ),
  );
}

/// Método para verificar y limpiar sesiones inválidas o corruptas al inicio
Future<void> _checkAndCleanSessionAtStartup() async {
  try {
    // Obtener el cliente de Supabase
    final client = SupabaseAuth.client;
    
    // Verificar si hay una sesión actual
    final currentUser = client.auth.currentUser;
    final currentSession = client.auth.currentSession;
    
    // Si hay usuario pero la sesión es nula o expirada, forzar limpieza
    if (currentUser != null && (currentSession == null || currentSession.isExpired)) {
      print('Detectada sesión inválida o expirada al inicio, limpiando...');
      await SupabaseAuth.signOut();
      
      // Limpiar datos de SharedPreferences relacionados con autenticación
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.contains('supabase') || key.contains('auth')) {
          await prefs.remove(key);
        }
      }
    }
  } catch (e) {
    print('Error durante verificación de sesión al inicio: $e');
  }
}

/// Provider para el ThemeProvider
final themeProvider = ChangeNotifierProvider<ThemeProvider>((ref) {
  final localStorage = SharedPreferencesStorage(ref.read(sharedPreferencesProvider));
  return ThemeProvider(localStorage);
});

/// Widget principal de la aplicación
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Obtenemos el proveedor de temas
    final themeProviderState = ref.watch(themeProvider);
    
    // Configuramos el tema de la aplicación
    return MaterialApp(
      title: 'Sacdia App',
      debugShowCheckedModeBanner: false,
      theme: themeProviderState.lightTheme,
      darkTheme: themeProviderState.darkTheme,
      themeMode: themeProviderState.themeMode,
      // Rutas principales de la aplicación
      home: const AuthGate(),
    );
  }
}
