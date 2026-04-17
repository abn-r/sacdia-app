import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/route_names.dart';
import '../realtime/feature_flags.dart';
import '../realtime/realtime_invalidation_handler.dart';
import '../realtime/realtime_ref.dart';
import '../utils/app_logger.dart';
import '../../features/notifications/presentation/providers/notifications_providers.dart';
import '../../features/notifications/presentation/providers/unread_notifications_count_provider.dart';

/// Top-level background message handler.
///
/// Must be a top-level function (not a class method or closure) because
/// Firebase Messaging calls it in an isolate separate from the main app.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // INVALIDATE data messages must be staged BEFORE the notification-null guard
  // below because they carry no notification object by design. Riverpod is NOT
  // accessible from this isolate — we write to SharedPreferences and drain on
  // the next app resume (see RealtimeInvalidationHandler.drainPending).
  if (message.data['type'] == 'cache_invalidate') {
    if (RealtimeFeatureFlags.realtimeInvalidationEnabled) {
      await RealtimeInvalidationHandler.stagePending(message);
    }
    return;
  }

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

  /// ID del registro devuelto por el backend al registrar el token.
  /// Necesario para el DELETE /users/me/fcm-tokens/:tokenId.
  static const _tokenIdPrefKey = 'fcm_registered_token_id';

  final Dio _dio;
  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Riverpod Ref — used to read/mutate notification providers from FCM events.
  final Ref _ref;

  /// Optional navigator key used to show snackbars and navigate on
  /// notification tap. Set this from your MaterialApp's navigatorKey or
  /// from GoRouter's navigatorKey so the service can reach the UI without
  /// needing a BuildContext.
  final GlobalKey<NavigatorState>? navigatorKey;

  PushNotificationService({
    required Dio dio,
    required Ref ref,
    this.navigatorKey,
    // ignore: avoid_unused_constructor_parameters
    SharedPreferences? prefs,
  })  : _dio = dio,
        _ref = ref;

  // ── StreamSubscription references ─────────────────────────────────────────

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSub;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Initialize FCM. Call this AFTER the user is authenticated.
  ///
  /// Safe to call multiple times — subsequent calls are idempotent because
  /// the Firebase SDK returns the same token while it hasn't rotated.
  Future<void> initialize() async {
    AppLogger.i('Inicializando FCM', tag: _tag);

    // Cancel any previous listeners before re-subscribing to prevent
    // duplicate handlers accumulating across login/logout/OAuth cycles.
    await _cancelSubscriptions();

    // Register the background handler first.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 1. Request permission (required on iOS; Android 13+ also needs it).
    await _requestPermission();

    // 3. Listen for token refresh BEFORE attempting getToken() so that even
    //    if the APNS token isn't ready yet we catch the token once it arrives
    //    (e.g. after app reinstall, token rotation, or late APNS delivery).
    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
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
    _onMessageSub =
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 5. Handle taps on notifications when app is in background (not terminated).
    _onMessageOpenedAppSub =
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // 6. Handle tap on notification that launched the app from terminated state.
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
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
    final tokenId = await _secureStorage.read(key: _tokenIdPrefKey);

    if ((token == null || token.isEmpty) && (tokenId == null || tokenId.isEmpty)) {
      AppLogger.i(
        'No hay token FCM registrado, saltando unregister',
        tag: _tag,
      );
      return;
    }

    try {
      AppLogger.i('Desregistrando token FCM del backend', tag: _tag);

      if (tokenId != null && tokenId.isNotEmpty) {
        // Ruta preferida: DELETE /users/me/fcm-tokens/:tokenId
        await _dio.delete('/users/me/fcm-tokens/$tokenId');
      } else if (token != null && token.isNotEmpty) {
        // Fallback para tokens registrados antes de persistir el ID:
        // DELETE /users/me/fcm-tokens/by-token con el token en el body.
        await _dio.delete(
          '/users/me/fcm-tokens/by-token',
          data: {'token': token},
        );
      }

      await _secureStorage.delete(key: _tokenPrefKey);
      await _secureStorage.delete(key: _tokenIdPrefKey);
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
      await _secureStorage.delete(key: _tokenIdPrefKey);
    } catch (e) {
      AppLogger.w('Error inesperado al desregistrar token',
          tag: _tag, error: e);
      await _secureStorage.delete(key: _tokenPrefKey);
      await _secureStorage.delete(key: _tokenIdPrefKey);
    }
  }

  /// Cancels all active stream subscriptions and releases resources.
  ///
  /// Call this on logout so listeners accumulated across sessions are cleaned up.
  Future<void> dispose() async {
    await _cancelSubscriptions();
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<void> _cancelSubscriptions() async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    await _onMessageSub?.cancel();
    _onMessageSub = null;
    await _onMessageOpenedAppSub?.cancel();
    _onMessageOpenedAppSub = null;
  }

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
      final response = await _dio.post(
        '/users/me/fcm-tokens',
        data: {'token': token},
      );

      // Persistir el token localmente.
      await _secureStorage.write(key: _tokenPrefKey, value: token);

      // El backend devuelve el ID del registro — persiste para poder hacer DELETE
      // por ID al desregistrar (más confiable que buscar por valor del token).
      final responseData = response.data;
      final tokenId = responseData is Map<String, dynamic>
          ? (responseData['id'] as dynamic)?.toString() ??
              (responseData['data'] is Map<String, dynamic>
                  ? (responseData['data']['id'] as dynamic)?.toString()
                  : null)
          : null;

      if (tokenId != null && tokenId.isNotEmpty) {
        await _secureStorage.write(key: _tokenIdPrefKey, value: tokenId);
        AppLogger.i('Token FCM registrado exitosamente (id=$tokenId)', tag: _tag);
      } else {
        AppLogger.i('Token FCM registrado exitosamente (sin id en respuesta)', tag: _tag);
      }
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

    // cache_invalidate data messages are intercepted BEFORE the notification-null
    // guard because they intentionally carry no notification payload.
    // They are handled silently — no inbox entry, no badge, no snackbar.
    if (message.data['type'] == 'cache_invalidate') {
      if (RealtimeFeatureFlags.realtimeInvalidationEnabled) {
        RealtimeInvalidationHandler.handleForeground(
          message,
          RealtimeRef.fromRef(_ref),
        );
      }
      return;
    }

    final notification = message.notification;
    if (notification == null) return;

    // Increment unread count optimistically and refresh inbox if it is alive.
    _ref.read(unreadNotificationsCountProvider.notifier).increment();
    _ref.invalidate(notificationsInboxProvider);

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

  // ── Notification route allowlist ─────────────────────────────────────────

  /// Static routes (no path parameters) that a push notification payload is
  /// allowed to navigate to. Any route NOT in this set (or not matching one
  /// of [_allowedParametricRoutePatterns]) is silently dropped.
  ///
  /// SECURITY: never navigate to an arbitrary route received from a remote
  /// message without validating it first. A compromised or malformed
  /// notification could otherwise push sensitive or unintended screens.
  static const Set<String> _allowedStaticRoutes = {
    // Primary tabs
    RouteNames.homeDashboard,
    RouteNames.homeClasses,
    RouteNames.homeActivities,
    RouteNames.homeProfile,
    // Quick-access modules
    RouteNames.homeMembers,
    RouteNames.homeClub,
    RouteNames.homeEvidences,
    RouteNames.homeFinances,
    RouteNames.homeUnits,
    RouteNames.homeInsurance,
    RouteNames.homeInventory,
    RouteNames.homeResources,
    RouteNames.homeHonors,
    RouteNames.homeCertifications,
    RouteNames.homeCamporees,
    RouteNames.homeAchievements,
    // Other top-level destinations
    RouteNames.transferRequests,
    RouteNames.investiturePendingList,
    RouteNames.notificationsInbox,
    RouteNames.roleAssignments,
    RouteNames.coordinator,
    RouteNames.coordinatorSla,
    RouteNames.coordinatorEvidenceReview,
    RouteNames.coordinatorCamporeeApprovals,
  };

  // ── Notification type handlers ───────────────────���───────────────────────

  /// Notification types that require custom navigation logic beyond simple
  /// route pushing. These types are resolved by [_handleTypedNotification].
  static const Set<String> _handledNotificationTypes = {
    'member_of_month',
    'member_of_month_director',
    'achievement_unlocked',
  };

  /// RegExp patterns for routes that carry path parameters.
  ///
  /// Each pattern must match the entire route string (anchored with ^ and $).
  /// Only add patterns for routes whose parameter values can safely come from
  /// a server-controlled push payload (i.e., no client-side secret IDs).
  static final List<RegExp> _allowedParametricRoutePatterns = [
    // /camporee/<integer>
    RegExp(r'^/camporee/\d+$'),
    // /camporee/<integer>/members
    RegExp(r'^/camporee/\d+/members$'),
    // /class/<integer>
    RegExp(r'^/class/\d+$'),
    // /honor/<integer>
    RegExp(r'^/honor/\d+$'),
    // /achievement/<integer>
    RegExp(r'^/achievement/\d+$'),
    // /certification/<integer>
    RegExp(r'^/certification/\d+$'),
    // /club/<alphanumeric slug or UUID>
    RegExp(r'^/club/[\w\-]+$'),
    // /transfer/<integer>
    RegExp(r'^/transfer/\d+$'),
    // /units/member-of-month/<clubId>/<sectionId>
    RegExp(r'^/units/member-of-month/\d+/\d+$'),
    // /notifications (already static, included for completeness via parametric path)
  ];

  /// Returns true when [route] is safe to navigate to from a notification.
  bool _isAllowedRoute(String route) {
    if (_allowedStaticRoutes.contains(route)) return true;
    for (final pattern in _allowedParametricRoutePatterns) {
      if (pattern.hasMatch(route)) return true;
    }
    return false;
  }

  void _handleNotificationTap(RemoteMessage message) {
    AppLogger.i(
      'Notificación tapeada: ${message.data}',
      tag: _tag,
    );

    final data = message.data;

    // Check for typed notification first (member_of_month, etc.)
    final type = data['type'] as String?;
    if (type != null && _handledNotificationTypes.contains(type)) {
      _handleTypedNotification(type, data);
      return;
    }

    final route = data['route'] as String?;

    if (route == null || route.isEmpty) return;

    // SECURITY: validate the route against the allowlist before navigating.
    // An attacker with access to the FCM project could craft a payload with an
    // arbitrary route string; rejecting unknown routes prevents unintended
    // navigation to sensitive or non-existent screens.
    if (!_isAllowedRoute(route)) {
      AppLogger.w(
        'Ruta de notificación rechazada (no está en el allowlist): "$route"',
        tag: _tag,
      );
      return;
    }

    final navigator = navigatorKey?.currentState;
    if (navigator == null) return;

    // Use pushNamed so the GoRouter handles the route resolution.
    // The payload 'route' must match a registered GoRouter path
    // (e.g. '/home/dashboard', '/home/classes', '/camporee/42').
    navigator.pushNamed(route);
  }

  /// Handles notification types that require custom navigation logic.
  ///
  /// Supported types:
  /// - `member_of_month`: navigate to member of month history for the section.
  ///   Payload: `{ type, club_id, section_id, month, year }`
  /// - `member_of_month_director`: navigate to the section's units list.
  ///   Payload: `{ type, club_id, section_id, month, year }`
  void _handleTypedNotification(String type, Map<String, dynamic> data) {
    final navigator = navigatorKey?.currentState;
    if (navigator == null) return;

    AppLogger.i('Manejando notificación tipada: $type', tag: _tag);

    switch (type) {
      case 'member_of_month':
        // Navigate to member of month history screen using the concrete path.
        final clubId = _parseInt(data['club_id']);
        final sectionId = _parseInt(data['section_id']);
        if (clubId == null || sectionId == null) {
          AppLogger.w(
            'Notificación member_of_month sin club_id/section_id válidos',
            tag: _tag,
          );
          return;
        }
        navigator.pushNamed(
          RouteNames.memberOfMonthHistoryPath(clubId, sectionId),
        );

      case 'member_of_month_director':
        // Navigate to the units list for the section
        navigator.pushNamed(RouteNames.homeUnits);

      case 'achievement_unlocked':
        // Navigate to the achievements screen, optionally deep-linking to
        // the specific achievement detail.
        // Payload: { type, achievement_id, achievement_name }
        final achievementId = _parseInt(data['achievement_id']);
        if (achievementId != null) {
          navigator.pushNamed(
            RouteNames.achievementDetailPath(achievementId),
          );
        } else {
          // Fallback: open the achievements list
          navigator.pushNamed(RouteNames.homeAchievements);
        }

      default:
        AppLogger.w('Tipo de notificación no manejado: $type', tag: _tag);
    }
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  // ── Debug helpers ─────────────────────────────────────────────────────────

  /// Returns the current FCM token. Useful for debugging.
  Future<String?> getToken() => FirebaseMessaging.instance.getToken();

  /// Returns the token that was last successfully registered with the backend.
  Future<String?> get registeredToken =>
      _secureStorage.read(key: _tokenPrefKey);
}
