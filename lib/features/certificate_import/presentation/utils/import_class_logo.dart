import 'package:sacdia_app/core/theme/app_colors.dart';

final _assetCodePattern = RegExp(r'^(AV|CQ|GM)-\d{2}$');

/// Local logo asset of a catalog class, or null when there is none.
///
/// The backend `asset_code` is the canonical contract; the name map covers
/// payloads that do not send it. Same rule as the post-registration flow.
String? importClassLogoAsset({String? assetCode, String? name}) {
  final code = assetCode?.trim().toUpperCase();
  if (code != null && _assetCodePattern.hasMatch(code)) {
    return 'assets/img/logos-clases/$code.png';
  }
  return name == null ? null : AppColors.classLogoAsset(name);
}
