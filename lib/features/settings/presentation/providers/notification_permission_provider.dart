import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/utils/app_logger.dart';

/// What the notification settings screen asks the operating system.
///
/// A seam so tests can say "the phone denied notifications" without Firebase.
abstract class NotificationPermissionGate {
  /// The user turned notifications off for the app in the phone settings.
  Future<bool> isDenied();

  /// Opens the app's page in the phone settings.
  Future<void> openSettings();
}

class SystemNotificationPermissionGate implements NotificationPermissionGate {
  const SystemNotificationPermissionGate();

  @override
  Future<bool> isDenied() async {
    try {
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.denied;
    } catch (e) {
      // Unknown is not "denied": never show a warning we cannot back up.
      AppLogger.w('No se pudo leer el permiso de notificaciones: $e',
          tag: 'NotifPermission');
      return false;
    }
  }

  @override
  Future<void> openSettings() async {
    await openAppSettings();
  }
}

final notificationPermissionGateProvider = Provider<NotificationPermissionGate>(
  (ref) => const SystemNotificationPermissionGate(),
);
