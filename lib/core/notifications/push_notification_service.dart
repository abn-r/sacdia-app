import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_logger.dart';

/// Top-level background message handler.
///
/// Must be a top-level function (not a class method or closure) because
/// Firebase Messaging calls it in an isolate separate from the main app.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialized by the time this is called.
  // Just log in debug — the OS notification tray handles display.
  if (kDebugMode) {
    AppLogger.i(
      'Background message: ${message.messageId} — ${message.notification?.title}',
      tag: 'FCM',
    );
  }
}

/// Service that owns the full FCM lifecycle:
/// - Requesting permission (iOS)
/// - Registering / refreshing the token with the backend
/// - Handling foreground messages (snackbar)
/// - Handling notification taps (navigation)
/// - Unregistering token on logout
class PushNotificationService {
  static const _tag = 'PushNotificationService';
  static const _tokenPrefKey = 'fcm_registered_token';

  final Dio _dio;
  final SharedPreferences _prefs;
  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Optional navigator key used to show snackbars and navigate on
  /// notification tap. Set this from your MaterialApp's navigatorKey or
  /// from GoRouter's navigatorKey so the service can reach the UI without
  /// needing a BuildContext.
  final GlobalKey<NavigatorState>? navigatorKey;

  PushNotificationService({
    required Dio dio,
    required SharedPreferences prefs,
    this.navigatorKey,
  })  : _dio = dio,
        _prefs = prefs;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Initialize FCM. Call this AFTER the user is authenticated.
  ///
  /// Safe to call multiple times — subsequent calls are idempotent because
  /// the Firebase SDK returns the same token while it hasn't rotated.
  Future<void> initialize() async {
    AppLogger.i('Inicializando FCM', tag: _tag);

    // Register the background handler first.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 1. Request permission (required on iOS; Android 13+ also needs it).
    await _requestPermission();

    // 3. Listen for token refresh BEFORE attempting getToken() so that even
    //    if the APNS token isn't ready yet we catch the token once it arrives
    //    (e.g. after app reinstall, token rotation, or late APNS delivery).
    FirebaseMessaging.instance.onTokenRefresh.listen(
      (newToken) async {
        AppLogger.i('Token FCM rotado, re-registrando', tag: _tag);
        await _registerTokenWithBackend(newToken);
      },
      onError: (Object e) {
        AppLogger.w('Error en onTokenRefresh', tag: _tag, error: e);
      },
    );

    // 2. Get current token and register with backend.
    //    On iOS, the APNS token is resolved asynchronously by the OS and may
    //    not be available immediately after permission is granted.  Calling
    //    getToken() while APNS is unresolved throws
    //    [firebase_messaging/apns-token-not-set], crashing the app.
    //    Strategy: wait for APNS with a short retry loop; if it never arrives
    //    within the deadline, log a warning and skip — onTokenRefresh above
    //    will deliver the token later without any extra work.
    await _getFcmTokenSafely();

    // 4. Handle messages arriving while app is in the foreground.
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 5. Handle taps on notifications when app is in background (not terminated).
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // 6. Handle tap on notification that launched the app from terminated state.
    final initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      // Defer navigation until the widget tree is fully built.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleNotificationTap(initialMessage);
      });
    }

    AppLogger.i('FCM inicializado correctamente', tag: _tag);
  }

  /// Unregister the FCM token from the backend. Call this on logout.
  Future<void> unregisterToken() async {
    final token = await _secureStorage.read(key: _tokenPrefKey);
    if (token == null || token.isEmpty) {
      AppLogger.i(
        'No hay token FCM registrado, saltando unregister',
        tag: _tag,
      );
      return;
    }

    try {
      AppLogger.i('Desregistrando token FCM del backend', tag: _tag);
      await _dio.delete(
        '/fcm-tokens/by-token',
        data: {'token': token},
      );
      await _secureStorage.delete(key: _tokenPrefKey);
      AppLogger.i('Token FCM desregistrado', tag: _tag);
    } on DioException catch (e) {
      // Non-critical: a stale token in the backend won't cause harm.
      AppLogger.w(
        'Error al desregistrar token FCM (${e.response?.statusCode})',
        tag: _tag,
        error: e,
      );
      // Still remove locally so we don't keep retrying a bad token.
      await _secureStorage.delete(key: _tokenPrefKey);
    } catch (e) {
      AppLogger.w('Error inesperado al desregistrar token', tag: _tag, error: e);
      await _secureStorage.delete(key: _tokenPrefKey);
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Obtains the FCM token in a crash-safe way.
  ///
  /// On iOS, Firebase requires the APNS token to be registered with the OS
  /// before it can mint an FCM token.  That handshake is asynchronous and can
  /// lag several seconds after the permission prompt, especially on first
  /// launch or after reinstall.  Calling [FirebaseMessaging.getToken] too
  /// early throws `[firebase_messaging/apns-token-not-set]`.
  ///
  /// This method:
  ///  1. On iOS only — polls [getAPNSToken] up to [_apnsMaxRetries] times
  ///     with [_apnsRetryDelay] between attempts.
  ///  2. Wraps [getToken] in a try-catch on all platforms.
  ///  3. Returns without throwing if the APNS token never arrives — the
  ///     [onTokenRefresh] listener registered in [initialize] will deliver the
  ///     token asynchronously when the OS is ready.
  static const int _apnsMaxRetries = 5;
  static const Duration _apnsRetryDelay = Duration(seconds: 2);

  /// Returns true when the app is running inside the iOS Simulator.
  ///
  /// The Simulator never delivers an APNS token — this is an Apple OS
  /// limitation that cannot be worked around. Detecting it early avoids
  /// the full retry wait on every dev launch.
  ///
  /// Detection strategy: `SIMULATOR_DEVICE_NAME` is always set in the
  /// process environment when running inside Xcode Simulator, and is
  /// never present on real hardware or Android.
  bool get _isIOSSimulator =>
      Platform.isIOS &&
      Platform.environment.containsKey('SIMULATOR_DEVICE_NAME');

  Future<void> _getFcmTokenSafely() async {
    if (Platform.isIOS) {
      // iOS Simulator never provides an APNS token — bail out immediately
      // so we don't waste 10 s on every dev launch.
      if (_isIOSSimulator) {
        AppLogger.i(
          'Push notifications no disponibles en iOS Simulator. '
          'Usa un dispositivo físico para probar FCM.',
          tag: _tag,
        );
        return;
      }

      String? apnsToken;
      for (var attempt = 1; attempt <= _apnsMaxRetries; attempt++) {
        apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        if (apnsToken != null) {
          AppLogger.i(
            'APNS token disponible (intento $attempt)',
            tag: _tag,
          );
          break;
        }
        AppLogger.w(
          'APNS token no disponible aún (intento $attempt/$_apnsMaxRetries), '
          'reintentando en ${_apnsRetryDelay.inSeconds}s…',
          tag: _tag,
        );
        await Future<void>.delayed(_apnsRetryDelay);
      }

      if (apnsToken == null) {
        AppLogger.w(
          'APNS token no llegó tras $_apnsMaxRetries intentos. '
          'El token FCM se registrará vía onTokenRefresh cuando el OS esté listo.',
          tag: _tag,
        );
        return;
      }
    }

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _registerTokenWithBackend(token);
      } else {
        AppLogger.w('FCM token no disponible aún', tag: _tag);
      }
    } catch (e) {
      // Non-fatal: onTokenRefresh will deliver the token when the OS is ready.
      AppLogger.w(
        'No se pudo obtener el token FCM ahora — se registrará vía onTokenRefresh.',
        tag: _tag,
        error: e,
      );
    }
  }

  Future<void> _requestPermission() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();

    // If already determined, don't re-prompt.
    if (settings.authorizationStatus != AuthorizationStatus.notDetermined) {
      AppLogger.i(
        'Permiso FCM ya determinado: ${settings.authorizationStatus.name}',
        tag: _tag,
      );
      return;
    }

    final result = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    AppLogger.i(
      'Permiso FCM solicitado: ${result.authorizationStatus.name}',
      tag: _tag,
    );
  }

  Future<void> _registerTokenWithBackend(String token) async {
    // Avoid re-registering the same token unnecessarily.
    final savedToken = await _secureStorage.read(key: _tokenPrefKey);
    if (savedToken == token) {
      AppLogger.i('Token FCM ya registrado, sin cambios', tag: _tag);
      return;
    }

    try {
      AppLogger.i('Registrando token FCM en backend', tag: _tag);
      await _dio.post(
        '/fcm-tokens',
        data: {'token': token},
      );
      await _secureStorage.write(key: _tokenPrefKey, value: token);
      AppLogger.i('Token FCM registrado exitosamente', tag: _tag);
    } on DioException catch (e) {
      AppLogger.w(
        'Error al registrar token FCM (${e.response?.statusCode})',
        tag: _tag,
        error: e,
      );
    } catch (e) {
      AppLogger.w('Error inesperado al registrar token', tag: _tag, error: e);
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    AppLogger.i(
      'Mensaje FCM en foreground: ${message.notification?.title}',
      tag: _tag,
    );

    final notification = message.notification;
    if (notification == null) return;

    final context = navigatorKey?.currentContext;
    if (context == null) return;

    // Show a SnackBar so the user sees the notification while using the app.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notification.title != null)
              Text(
                notification.title!,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            if (notification.body != null) Text(notification.body!),
          ],
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Ver',
          onPressed: () => _handleNotificationTap(message),
        ),
      ),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    AppLogger.i(
      'Notificación tapeada: ${message.data}',
      tag: _tag,
    );

    final data = message.data;
    final route = data['route'] as String?;

    if (route == null || route.isEmpty) return;

    final navigator = navigatorKey?.currentState;
    if (navigator == null) return;

    // Use pushNamed so the router handles the route resolution.
    // The payload 'route' should match a GoRouter named route path
    // (e.g. '/home/dashboard', '/home/classes').
    navigator.pushNamed(route);
  }

  // ── Debug helpers ─────────────────────────────────────────────────────────

  /// Returns the current FCM token. Useful for debugging.
  Future<String?> getToken() => FirebaseMessaging.instance.getToken();

  /// Returns the token that was last successfully registered with the backend.
  Future<String?> get registeredToken => _secureStorage.read(key: _tokenPrefKey);
}

