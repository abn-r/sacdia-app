import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

import 'sac_profile_image.dart';

/// Round photo with the initials as fallback (no photo, loading, or error).
class InstructorAvatar extends StatelessWidget {
  const InstructorAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 36,
  });

  final String name;
  final String? photoUrl;
  final double size;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final initials = ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.surfaceVariant,
          shape: BoxShape.circle,
        ),
        child: Text(
          _initials,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: c.textSecondary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
    final url = photoUrl;
    if (url == null) return initials;
    return ExcludeSemantics(
      child: ClipOval(
        child: SacProfileImage(
          imageUrl: url,
          width: size,
          height: size,
          memCacheWidth: (size * 3).round(),
          placeholder: (_, __) => initials,
          errorWidget: (_, __, ___) => initials,
        ),
      ),
    );
  }
}
