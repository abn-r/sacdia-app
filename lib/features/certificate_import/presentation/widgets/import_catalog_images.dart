import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_badge_image.dart';

import '../utils/import_class_logo.dart';

/// Badge of a catalog honor. Never squashed or masked: it keeps its own
/// silhouette (`BoxFit.contain`, only one side in the memory cache). The URL
/// comes with the row (`honor.honor_image`) or from the picked honor; without
/// it the badge is a gray placeholder.
class ImportHonorBadge extends StatelessWidget {
  const ImportHonorBadge({
    super.key,
    this.imageUrl,
    this.size = 40,
  });

  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return HonorBadgeImage(
      imageUrl: imageUrl,
      width: size,
      height: size,
      memCacheWidth: (size * 3).round(),
      fallbackColor: c.textTertiary,
      fallbackBackgroundColor: c.surfaceVariant,
      fallbackIconSize: size * 0.5,
    );
  }
}

/// Logo of a class, from its asset code or name. Kept at its own proportions
/// (`BoxFit.contain`); a gray placeholder when the class has no logo.
class ImportClassLogo extends StatelessWidget {
  const ImportClassLogo({
    super.key,
    this.assetCode,
    this.name,
    this.size = 40,
  });

  final String? assetCode;
  final String? name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final asset = importClassLogoAsset(assetCode: assetCode, name: name);
    Widget placeholder() => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: c.surfaceVariant,
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          ),
          alignment: Alignment.center,
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedUserGroup,
            size: size * 0.5,
            color: c.textTertiary,
          ),
        );
    if (asset == null) return placeholder();
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        cacheWidth: (size * 3).round(),
        errorBuilder: (_, __, ___) => placeholder(),
      ),
    );
  }
}
