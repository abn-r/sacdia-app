import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../domain/utils/device_label.dart';

/// Lo que este teléfono manda al vincularse: plataforma, versión de la app y un
/// nombre sugerido. Nada identifica a la persona.
class DevicePairingMeta extends Equatable {
  /// `ios` | `android`.
  final String platform;
  final String appVersion;
  final String defaultLabel;

  const DevicePairingMeta({
    required this.platform,
    required this.appVersion,
    required this.defaultLabel,
  });

  @override
  List<Object?> get props => [platform, appVersion, defaultLabel];
}

/// Plataforma, versión y nombre sugerido (modelo del teléfono). Si el plugin
/// falla (emulador, web) cae a valores neutros: el servidor solo exige que
/// `platform` sea `ios` o `android`.
final devicePairingMetaProvider =
    FutureProvider.autoDispose<DevicePairingMeta>((ref) async {
  final platform = Platform.isIOS ? 'ios' : 'android';
  var version = '0.0.0';
  var model = '';
  try {
    final pkg = await PackageInfo.fromPlatform();
    version = pkg.version;
  } catch (_) {}
  try {
    final plugin = DeviceInfoPlugin();
    if (Platform.isIOS) {
      final info = await plugin.iosInfo;
      model = info.name.trim().isNotEmpty ? info.name : info.utsname.machine;
    } else if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      model = '${info.manufacturer} ${info.model}';
    }
  } catch (_) {}
  return DevicePairingMeta(
    platform: platform,
    // `app_version` es varchar(32) en el servidor.
    appVersion: version.length > 32 ? version.substring(0, 32) : version,
    defaultLabel: sanitizeDeviceLabel(model),
  );
});
