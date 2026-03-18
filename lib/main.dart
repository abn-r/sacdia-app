import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/auth/supabase_auth.dart';
import 'core/config/router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/utils/app_logger.dart';
import 'firebase_options.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'providers/storage_provider.dart';

/// Punto de entrada principal de la aplicación
Future<void> main() async {
  // Aseguramos que las dependencias de Flutter estén inicializadas
  WidgetsFlutterBinding.ensureInitialized();

  // Paralelizamos operaciones independientes: orientación, Supabase y SharedPreferences
  final results = await Future.wait([
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]),
    SupabaseAuth.initialize(),
    SharedPreferences.getInstance(),
  ]);

  final sharedPreferences = results[2] as SharedPreferences;

  // Firebase depende de Supabase (accede al estado de auth) — se ejecuta después
  await _initializeFirebaseAndPrintDebugTokens();

  // Recuperar estado de cierre de sesión manual
  final wasManuallyLoggedOut =
      sharedPreferences.getBool('user_manually_logged_out') ?? false;

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

  // La verificación de sesión no necesita bloquear el primer frame
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _checkAndCleanSessionAtStartup();
  });
}

Future<void> _initializeFirebaseAndPrintDebugTokens() async {
  const tag = 'FCMDebug';

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kDebugMode) AppLogger.i('Firebase initialized', tag: tag);
  } catch (e) {
    if (kDebugMode) {
      AppLogger.w(
        'Firebase no pudo inicializarse. Verifica google-services.json (Android) y GoogleService-Info.plist (iOS).',
        tag: tag,
        error: e,
      );
    }
    return;
  }

  try {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    NotificationSettings effectiveSettings = settings;

    if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
      effectiveSettings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    if (kDebugMode) {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      AppLogger.i(
        'FCM permission: ${effectiveSettings.authorizationStatus.toString().split('.').last}',
        tag: tag,
      );
      AppLogger.i('FCM_TOKEN: ${fcmToken ?? 'null'}', tag: tag);
    }
  } catch (e) {
    if (kDebugMode) {
      AppLogger.w('No fue posible obtener FCM token', tag: tag, error: e);
    }
  }

  if (kDebugMode) {
    final currentToken = SupabaseAuth.currentSession?.accessToken;
    if (currentToken != null && currentToken.isNotEmpty) {
      AppLogger.i('JWT_ACCESS_TOKEN: $currentToken', tag: tag);
    }

    SupabaseAuth.onAuthStateChange.listen((authState) {
      final accessToken = authState.session?.accessToken;
      if (accessToken != null && accessToken.isNotEmpty) {
        AppLogger.i('JWT_ACCESS_TOKEN: $accessToken', tag: tag);
      }
    });
  }
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
    if (currentUser != null &&
        (currentSession == null || currentSession.isExpired)) {
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
    // Silenciar errores de verificación de sesión
  }
}

/// Unified scroll behavior — iOS-inspired bouncing physics on all platforms.
class _AppScrollBehavior extends ScrollBehavior {
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }
}

/// Widget principal de la aplicación
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeNotifierProvider);
    final router = ref.watch(routerProvider);

    // Adaptar iconos del status bar al tema actual
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    SystemChrome.setSystemUIOverlayStyle(
      isDark
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
            ),
    );

    return ScrollConfiguration(
      behavior: _AppScrollBehavior(),
      child: MaterialApp.router(
        title: 'Sacdia App',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        routerConfig: router,
        locale: const Locale('es'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('es'),
          Locale('en'),
        ],
      ),
    );
  }
}
