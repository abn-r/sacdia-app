import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_network_image.dart';

class MasterHonorLogo extends StatelessWidget {
  const MasterHonorLogo({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.size,
    required this.color,
  });

  final String? imageUrl;
  final String name;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final image = imageUrl?.trim() ?? '';
    final width = size * 1.25;
    final fallback = SizedBox(
      width: width,
      height: size,
      child: MasterHonorInitialsBox(
        initials: masterHonorInitials(name),
        color: color,
      ),
    );

    if (image.isEmpty) return fallback;

    return SizedBox(
      width: width,
      height: size,
      child: SacNetworkImage(
        imageUrl: image,
        fit: BoxFit.contain,
        memCacheWidth: (width * 3).round(),
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
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(60), width: 1.5),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: 24,
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
