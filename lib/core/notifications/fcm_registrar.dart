import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thin seam over the token lifecycle of [FirebaseMessaging].
///
/// `firebase_messaging` 17 replaces `getToken` / `onTokenRefresh` /
/// `deleteToken` with `register()` + `onRegistered` (which yields the Firebase
/// Installation ID, FID) and `unregister()` + `onUnregistered`. Keeping the
/// calls behind this interface lets `PushNotificationService` be unit-tested
/// without a Firebase app. Message listeners (`onMessage`, `onMessageOpenedApp`,
/// `getInitialMessage`) are NOT part of the seam; they stay on
/// `FirebaseMessaging` directly.
abstract class FcmRegistrar {
  /// Registers this app instance with FCM. The FID is delivered through
  /// [onRegistered] (re-emitted on every call).
  Future<void> register();

  /// Unregisters this app instance from FCM.
  Future<void> unregister();

  /// Emits the FID each time the app instance is (re)registered.
  Stream<String> get onRegistered;

  /// Emits the FID that stopped being active after [unregister].
  Stream<String> get onUnregistered;

  /// iOS APNs token (`null` on Android and while the OS has not delivered it).
  Future<String?> getAPNSToken();
}

/// Default implementation backed by [FirebaseMessaging.instance].
///
/// The instance is resolved lazily on every call so constructing this class
/// never touches Firebase (tests and early bootstrap are safe).
class FirebaseFcmRegistrar implements FcmRegistrar {
  const FirebaseFcmRegistrar();

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  @override
  Future<void> register() => _messaging.register();

  @override
  Future<void> unregister() => _messaging.unregister();

  @override
  Stream<String> get onRegistered => _messaging.onRegistered;

  @override
  Stream<String> get onUnregistered => _messaging.onUnregistered;

  @override
  Future<String?> getAPNSToken() => _messaging.getAPNSToken();
}

/// Registrar used by `PushNotificationService`. Override in tests.
final fcmRegistrarProvider = Provider<FcmRegistrar>(
  (ref) => const FirebaseFcmRegistrar(),
);
