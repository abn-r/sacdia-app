import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';

class ClassIdentityBadge extends StatelessWidget {
  final String className;
  final String? imageUrl;
  final double size;
  final double logoPadding;
  final double borderRadius;
  final List<List<dynamic>> fallbackIcon;

  const ClassIdentityBadge({
    super.key,
    required this.className,
    this.imageUrl,
    this.size = 48,
    this.logoPadding = 6,
    this.borderRadius = 14,
    this.fallbackIcon = HugeIcons.strokeRoundedSchool,
  });

  @override
  Widget build(BuildContext context) {
    final classColor = AppColors.classColor(className);
    final logoAsset = AppColors.classLogoAsset(className);
    final trimmedImageUrl = imageUrl?.trim();
    final cacheSize = (size * 3).round();

    Widget fallback() {
      if (logoAsset != null) {
        return Padding(
          padding: EdgeInsets.all(logoPadding),
          child: Image.asset(
            logoAsset,
            fit: BoxFit.contain,
            cacheWidth: cacheSize,
            cacheHeight: cacheSize,
          ),
        );
      }

      return Center(
        child: HugeIcon(
          icon: fallbackIcon,
          size: size * 0.5,
          color: classColor,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: classColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: classColor.withValues(alpha: 0.16)),
      ),
      child: trimmedImageUrl == null || trimmedImageUrl.isEmpty
          ? fallback()
          : ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: CachedNetworkImage(
                imageUrl: trimmedImageUrl,
                memCacheWidth: cacheSize,
                memCacheHeight: cacheSize,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => fallback(),
              ),
            ),
    );
  }
}
