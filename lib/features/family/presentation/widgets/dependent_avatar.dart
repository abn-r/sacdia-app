import 'package:flutter/material.dart';

import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_profile_image.dart';

/// Avatar circular de un menor: foto si existe, si no la inicial de su nombre.
class DependentAvatar extends StatelessWidget {
  const DependentAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 48,
  });

  final String name;
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = SacAccent.of(context);
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final fallback = Center(
      child: Text(
        initial,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: accent.color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );

    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accent.light,
          border: Border.all(color: context.sac.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: (imageUrl == null || imageUrl!.isEmpty)
            ? fallback
            : SacProfileImage(
                imageUrl: imageUrl!,
                width: size,
                height: size,
                errorWidget: (_, __, ___) => fallback,
                placeholder: (_, __) => fallback,
              ),
      ),
    );
  }
}
