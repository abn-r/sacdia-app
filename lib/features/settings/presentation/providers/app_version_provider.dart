import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Installed app version, read once from the platform.
///
/// The settings index shows `version`; the About screen shows `version (build)`.
final appPackageInfoProvider = FutureProvider.autoDispose<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

/// "1.0.0 (12)" or "—" while it loads.
String formatAppVersion(PackageInfo? info) =>
    info == null ? '—' : '${info.version} (${info.buildNumber})';
