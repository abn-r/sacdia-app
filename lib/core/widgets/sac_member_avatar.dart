import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_profile_image.dart';

/// Circular member avatar: cached profile photo or initials fallback.
///
/// Initials are the first letters of the first two words of [name],
/// uppercase. The fallback also shows while loading and on image error.
/// [ring] draws an accent-colored ring. Announced to screen readers as an
/// image labelled [semanticLabel] (defaults to [name]).
///
/// ```dart
/// SacMemberAvatar(imageUrl: member.photoUrl, name: member.fullName, size: 48)
/// ```
class SacMemberAvatar extends StatelessWidget {
  const SacMemberAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = 40,
    this.ring = false,
    this.semanticLabel,
  });

  final String? imageUrl;
  final String name;
  final double size;
  final bool ring;
  final String? semanticLabel;

  /// First letters of the first two words, uppercase. Empty name gives ''.
  static String initialsOf(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words
        .take(2)
        .map((w) => String.fromCharCode(w.runes.first))
        .join()
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final url = imageUrl;
    final hasImage = url != null && url.trim().isNotEmpty;
    final ringWidth = ring ? 2.0 : 0.0;
    final ringGap = ring ? 2.0 : 0.0;
    final inner = size - 2 * (ringWidth + ringGap);

    final initials = initialsOf(name);
    final fallback = Container(
      width: inner,
      height: inner,
      alignment: Alignment.center,
      decoration:
          BoxDecoration(color: c.surfaceVariant, shape: BoxShape.circle),
      // No name to take initials from: a person icon, not an empty circle.
      child: initials.isEmpty
          ? HugeIcon(
              icon: HugeIcons.strokeRoundedUser,
              size: inner * 0.5,
              color: c.textTertiary,
            )
          : Text(
              initials,
              style: TextStyle(
                fontSize: inner * 0.4,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
    );

    final avatar = ClipOval(
      child: SizedBox(
        width: inner,
        height: inner,
        child: hasImage
            ? SacProfileImage(
                imageUrl: url,
                width: inner,
                height: inner,
                memCacheWidth: (inner * 3).round(),
                placeholder: (_, __) => fallback,
                errorWidget: (_, __, ___) => fallback,
              )
            : fallback,
      ),
    );

    return Semantics(
      label: semanticLabel ?? name,
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: ring
            ? DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: SacAccent.of(context).color,
                    width: ringWidth,
                  ),
                ),
                child: Padding(padding: EdgeInsets.all(ringGap), child: avatar),
              )
            : avatar,
      ),
    );
  }
}
