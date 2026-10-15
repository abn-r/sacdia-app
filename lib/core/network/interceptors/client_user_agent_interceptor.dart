import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Builds the User-Agent the app sends to the API.
///
/// The backend reads it when it creates a session and shows the device in
/// "Sesiones activas". The default `Dart/x.y (dart:io)` says nothing, so
/// every session looked like an unknown device. The backend recognises
/// "iPhone", "iPad" and "Android" in the string.
String buildClientUserAgent({
  required String appVersion,
  required String platform,
  required String osVersion,
  String? deviceFamily,
  String? model,
}) {
  final parts = <String>[
    if (deviceFamily != null && deviceFamily.isNotEmpty) deviceFamily,
    '$platform $osVersion'.trim(),
    if (model != null && model.isNotEmpty) model,
  ];
  return 'SACDIA/$appVersion (${parts.join('; ')})';
}

/// Sets the User-Agent on every request. Device info is read once and
/// cached; if it fails the request goes out with the Dart default.
class ClientUserAgentInterceptor extends Interceptor {
  static Future<String?>? _cached;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final userAgent = await (_cached ??= _resolve());
    if (userAgent != null) {
      options.headers[HttpHeaders.userAgentHeader] = userAgent;
    }
    handler.next(options);
  }

  static Future<String?> _resolve() async {
    try {
      final pkg = await PackageInfo.fromPlatform();
      final plugin = DeviceInfoPlugin();
      if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        return buildClientUserAgent(
          appVersion: pkg.version,
          deviceFamily: info.model,
          platform: 'iOS',
          osVersion: info.systemVersion,
          model: info.utsname.machine,
        );
      }
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        return buildClientUserAgent(
          appVersion: pkg.version,
          platform: 'Android',
          osVersion: info.version.release,
          model: '${info.manufacturer} ${info.model}',
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
