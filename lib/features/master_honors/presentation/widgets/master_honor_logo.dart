import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_network_image.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

class MasterHonorLogo extends StatelessWidget {
  const MasterHonorLogo({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.size,
    required this.color,
    this.width,
  });

  final String? imageUrl;
  final String name;

  /// Height of the box.
  final double size;

  /// Box width; defaults to 5:4. The patch keeps its own oval inside it.
  final double? width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final image = imageUrl?.trim() ?? '';
    final boxWidth = width ?? size * 1.25;
    final fallback = SizedBox(
      width: boxWidth,
      height: size,
      child: MasterHonorInitialsBox(
        initials: masterHonorInitials(name),
        color: color,
      ),
    );

    if (image.isEmpty) return fallback;

    return SizedBox(
      width: boxWidth,
      height: size,
      child: SacNetworkImage(
        imageUrl: image,
        fit: BoxFit.contain,
        // Height only: giving the cache both sides decodes the patch into the
        // box and squashes its oval.
        memCacheHeight: (size * 3).round(),
        placeholder: (_, __) => fallback,
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }
}

class MasterHonorInitialsBox extends StatelessWidget {
  const MasterHonorInitialsBox({
    super.key,
    required this.initials,
    required this.color,
  });

  final String initials;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: color.withAlpha(60), width: 1.5),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: SacFontSize.displaySmall,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    );
  }
}

String masterHonorInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return 'M';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
}
