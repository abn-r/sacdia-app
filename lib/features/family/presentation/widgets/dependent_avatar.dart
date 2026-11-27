import 'package:flutter/material.dart';

import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_profile_image.dart';
import '../../../../core/widgets/sac_tone.dart';

/// Tamaño de la inicial respecto al diámetro del avatar.
const double kDependentAvatarInitialRatio = 0.38;

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
    // Theme-aware: the accent pastel in light, a tint over the dark surface
    // in dark (the pastel glares there).
    final tone = SacTonePalette.of(context, SacTone.accent);
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final fallback = Center(
      child: Text(
        initial,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: tone.onContainer,
              fontWeight: FontWeight.w700,
              // Grows with the circle: 16 in a list row (42), 24 in the
              // detail header (64). A fixed size looked lost in the large one.
              fontSize: size * kDependentAvatarInitialRatio,
            ),
      ),
    );

    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: tone.container,
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
