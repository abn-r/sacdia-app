import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/widgets/sac_network_image.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

/// Displays an honor badge without forcing an oval or circular mask.
///
/// Pathfinder/GM honors are usually oval patches, while Adventurer specialties
/// are often inverted triangles. The image asset already carries the correct
/// silhouette, usually with transparent pixels around it, so the UI must keep
/// the natural aspect and shape using [BoxFit.contain].
///
/// Supports raster (png/webp/jpg) and SVG URLs via [SacNetworkImage].
class HonorBadgeImage extends StatelessWidget {
  final String? imageUrl;
  final double width;
  final double height;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final EdgeInsetsGeometry padding;
  final Color fallbackColor;
  final Color? fallbackBackgroundColor;
  final double fallbackIconSize;
  final BorderRadiusGeometry fallbackBorderRadius;

  const HonorBadgeImage({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.memCacheWidth,
    this.memCacheHeight,
    this.padding = EdgeInsets.zero,
    required this.fallbackColor,
    this.fallbackBackgroundColor,
    this.fallbackIconSize = 24,
    this.fallbackBorderRadius =
        const BorderRadius.all(Radius.circular(AppTheme.radiusSM)),
  });

  bool get _hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!_hasImage) return _fallback(context);

    return SizedBox(
      width: width,
      height: height,
      child: Padding(
        padding: padding,
        child: SacNetworkImage(
          imageUrl: imageUrl!,
          memCacheWidth: memCacheWidth,
          memCacheHeight: memCacheHeight,
          fit: BoxFit.contain,
          errorWidget: (ctx, __, ___) => _fallback(ctx),
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: fallbackBackgroundColor ?? context.sac.ink100,
        borderRadius: fallbackBorderRadius,
      ),
      child: HugeIcon(
        icon: HugeIcons.strokeRoundedMedal05,
        color: fallbackColor,
        size: fallbackIconSize,
      ),
    );
  }
}
