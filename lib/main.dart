import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/utils/app_logger.dart';
import 'firebase_options.dart';
import 'providers/storage_provider.dart';

/// Punto de entrada principal de la aplicación
Future<void> main() async {
  // Aseguramos que las dependencias de Flutter estén inicializadas
  WidgetsFlutterBinding.ensureInitialized();

  // Paralelizamos operaciones independientes: orientación, SharedPreferences y
  // Firebase.initializeApp() — este último DEBE ocurrir antes de runApp().
  final results = await Future.wait([
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]),
    SharedPreferences.getInstance(),
    Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ),
  ]);

  final sharedPreferences = results[1] as SharedPreferences;

  // Diferimos la activación de AppCheck al post-frame: no bloquea el primer
  // frame y el handshake con el servidor de AppCheck puede tomar ~1-2 s.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _initializeFirebaseExtras();
  });

  // Ejecutamos la aplicación con la configuración inicial
  runApp(
    ProviderScope(
      overrides: [
        // Proporcionamos la instancia de SharedPreferences a la aplicación
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const MyApp(),
    ),
  );

  // La verificación de sesión no necesita bloquear el primer frame.
  // Reutilizamos la instancia ya cargada para evitar un segundo getInstance().
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _checkAndCleanSessionAtStartup(sharedPreferences);
  });
}

/// Activación de FirebaseAppCheck diferida al post-frame.
///
/// AppCheck no es requerido antes del primer frame; diferirlo elimina ~1-2 s
/// del cold start. FCM (permisos, token, listeners) es manejado íntegramente
/// por [PushNotificationService.initialize()] después de que el usuario
/// se autentica — no se duplica aquí.
Future<void> _initializeFirebaseExtras() async {
  const tag = 'FirebaseExtras';
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode
          ? AppleProvider.debug
          : AppleProvider.appAttest,
    );
    if (kDebugMode) AppLogger.i('FirebaseAppCheck activado', tag: tag);
  } catch (e) {
    if (kDebugMode) {
      AppLogger.w('FirebaseAppCheck no pudo activarse', tag: tag, error: e);
    }
  }
}

/// Verifica y limpia sesiones inválidas o corruptas al inicio.
///
/// Con Better Auth / Option C no hay cliente Supabase. Simplemente
/// verificamos si el access token almacenado localmente existe. La
/// validación real contra el servidor ocurre en [AuthNotifier.build()]
/// mediante GET /auth/me.
///
/// Recibe la instancia de [SharedPreferences] ya cargada en [main] para
/// evitar un segundo [SharedPreferences.getInstance]. La limpieza de
/// residuos de Supabase se ejecuta una única vez gracias al flag
/// `supabase_migration_done`.
Future<void> _checkAndCleanSessionAtStartup(SharedPreferences prefs) async {
  try {
    // La limpieza de residuos de Supabase solo necesita ocurrir una vez.
    if (prefs.getBool('supabase_migration_done') == true) return;

    final keys = prefs.getKeys().toList();
    for (final key in keys) {
      // Eliminar residuos de sesiones Supabase previas
      if (key.contains('supabase')) {
        await prefs.remove(key);
      }
    }

    await prefs.setBool('supabase_migration_done', true);
  } catch (e) {
    // Silenciar errores de verificación de sesión
  }
}

/// Unified scroll behavior — platform-aware physics (bouncing on iOS/macOS, clamping on Android).
class _AppScrollBehavior extends ScrollBehavior {
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
      default:
        return const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
    }
  }
}

/// Widget principal de la aplicación
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeNotifierProvider);
    final router = ref.watch(routerProvider);

    // Adaptar iconos del status bar al tema actual.
    // AnnotatedRegion is the declarative alternative to SystemChrome.setSystemUIOverlayStyle()
    // inside build() — it only propagates when the widget tree actually changes instead of
    // issuing a platform channel call on every rebuild.
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final overlayStyle = isDark
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
          );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: ScrollConfiguration(
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
      ),
    );
  }
}
