import 'package:easy_localization/easy_localization.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/utils/icon_helper.dart';
import '../../../../core/utils/ip_masker.dart';
import '../../../../core/utils/relative_time.dart';
import '../../domain/entities/active_session.dart';

/// Readable name of an open session: platform and client the backend could
/// read from the user agent ("Android", "iPhone", "Panel web · Chrome").
/// "Dispositivo desconocido" only when nothing is known.
String sessionDisplayName(ActiveSession session) {
  final raw = session.deviceName?.trim() ?? '';
  switch (session.deviceType) {
    case SessionDeviceType.web:
      // The backend names an unrecognised browser "Browser".
      if (raw.isEmpty || raw.toLowerCase() == 'browser') {
        return 'settings.security.web_panel'.tr();
      }
      return 'settings.security.web_panel_browser'
          .tr(namedArgs: {'browser': raw});
    case SessionDeviceType.ios:
      return raw.isNotEmpty ? raw : 'iOS';
    case SessionDeviceType.android:
      return raw.isNotEmpty ? raw : 'Android';
    case SessionDeviceType.unknown:
      return raw.isNotEmpty ? raw : 'settings.security.unknown_device'.tr();
  }
}

/// Where the session was opened: the location when the backend sends one,
/// otherwise the masked IP. Null when neither is known.
String? sessionPlace(ActiveSession session) {
  final location = session.location?.trim();
  if (location != null && location.isNotEmpty) return location;
  final ip = session.ipAddress?.trim();
  if (ip == null || ip.isEmpty) return null;
  return maskIpAddress(ip);
}

/// "Place · last used" for another session, "This device" for the current one.
String sessionSubtitle(ActiveSession session, {DateTime? now}) {
  if (session.isCurrent) return 'settings.security.this_device'.tr();
  final place = sessionPlace(session);
  final when = formatRelativeTime(session.lastActiveAt, now: now);
  return place == null ? when : '$place · $when';
}

HugeIconData sessionIcon(SessionDeviceType type) {
  switch (type) {
    case SessionDeviceType.ios:
      return HugeIcons.strokeRoundedSmartPhone01;
    case SessionDeviceType.android:
      return HugeIcons.strokeRoundedSmartPhone02;
    case SessionDeviceType.web:
      return HugeIcons.strokeRoundedLaptop;
    case SessionDeviceType.unknown:
      return HugeIcons.strokeRoundedDeviceAccess;
  }
}
