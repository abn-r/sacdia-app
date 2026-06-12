import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// Displays an honor badge without forcing an oval or circular mask.
///
/// Pathfinder/GM honors are usually oval patches, while Adventurer specialties
/// are often inverted triangles. The image asset already carries the correct
/// silhouette, usually with transparent pixels around it, so the UI must keep
/// the natural aspect and shape using [BoxFit.contain].
class HonorBadgeImage extends StatelessWidget {
  final String? imageUrl;
  final double width;
  final double height;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final EdgeInsetsGeometry padding;
  final Color fallbackColor;
  final Color fallbackBackgroundColor;
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
    this.fallbackBackgroundColor = const Color(0xFFF0F4F5),
    this.fallbackIconSize = 24,
    this.fallbackBorderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  bool get _hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!_hasImage) return _fallback();

    return SizedBox(
      width: width,
      height: height,
      child: Padding(
        padding: padding,
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          memCacheWidth: memCacheWidth,
          memCacheHeight: memCacheHeight,
          fit: BoxFit.contain,
          errorWidget: (_, __, ___) => _fallback(),
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: fallbackBackgroundColor,
        borderRadius: fallbackBorderRadius,
      ),
      child: HugeIcon(
        icon: HugeIcons.strokeRoundedAward01,
        color: fallbackColor,
        size: fallbackIconSize,
      ),
    );
  }
}
