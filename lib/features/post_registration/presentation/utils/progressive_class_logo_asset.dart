import 'package:sacdia_app/core/theme/app_colors.dart';

import '../../data/models/class_model.dart';

final _assetCodePattern = RegExp(r'^(AV|CQ|GM)-\d{2}$');

/// Resolves the local logo asset for a post-registration progressive class.
///
/// Prefer the backend `asset_code` when present because it is the canonical
/// class-image contract. Fall back to the existing name map for older payloads.
String? progressiveClassLogoAsset(ClassModel progressiveClass) {
  final assetCode = progressiveClass.assetCode?.trim().toUpperCase();
  if (assetCode != null && _assetCodePattern.hasMatch(assetCode)) {
    return 'assets/img/logos-clases/$assetCode.png';
  }

  return AppColors.classLogoAsset(progressiveClass.name);
}
