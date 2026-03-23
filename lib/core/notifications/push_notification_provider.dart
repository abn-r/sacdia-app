import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/dio_provider.dart';
import '../../providers/storage_provider.dart';
import 'push_notification_service.dart';

/// Global navigator key.
///
/// Assign this to MaterialApp / MaterialApp.router so that
/// [PushNotificationService] can show SnackBars and navigate
/// without requiring a BuildContext.
///
/// In main.dart (MyApp.build):
///   MaterialApp.router(
///     ...
///     // Note: GoRouter manages its own navigator; we expose the root key.
///   )
///
/// For GoRouter, pass this as `navigatorKey` to the GoRouter constructor.
final pushNavigatorKey = GlobalKey<NavigatorState>();

/// Provider for the [PushNotificationService] singleton.
///
/// Depends on:
/// - [dioProvider] — authenticated Dio instance (includes AuthInterceptor).
/// - [sharedPreferencesProvider] — to persist the registered FCM token.
/// - [pushNavigatorKey] — so the service can reach the UI layer.
final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  final dio = ref.watch(dioProvider);
  final prefs = ref.watch(sharedPreferencesProvider);

  return PushNotificationService(
    dio: dio,
    prefs: prefs,
    navigatorKey: pushNavigatorKey,
  );
});
