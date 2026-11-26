import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/theme/club_type.dart';
import '../../../../core/widgets/sac_tone.dart';

/// Letters of a club name for its tile: the first two of the first word
/// («Pléyades» reads «PL», «Estrella del Mar» reads «ES»).
String supervisionMonogramLetters(String name) {
  final word = name.trim().split(RegExp(r'\s+')).first;
  if (word.isEmpty) return '·';
  final runes = word.runes.take(2).toList();
  return String.fromCharCodes(runes).toUpperCase();
}

/// Initials of a person: first letter of the first two words («MH»).
String supervisionInitials(String fullName) {
  final words = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .take(2);
  if (words.isEmpty) return '·';
  return words
      .map((word) => String.fromCharCode(word.runes.first))
      .join()
      .toUpperCase();
}

/// Rounded square with the letters of a club («PL»). Grey, so the name next
/// to it leads; [dimmed] fades it for an inactive club. Decorative: the row's
/// own text names the club.
class SupervisionMonogram extends StatelessWidget {
  const SupervisionMonogram({
    super.key,
    required this.name,
    this.size = 40,
    this.dimmed = false,
  });

  final String name;
  final double size;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return ExcludeSemantics(
      child: Opacity(
        opacity: dimmed ? 0.55 : 1,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.surfaceVariant,
            borderRadius: BorderRadius.circular(AppTheme.radiusXS),
          ),
          child: Text(
            supervisionMonogramLetters(name),
            maxLines: 1,
            style: TextStyle(
              fontSize: SacFontSize.bodyMedium,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: c.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Round avatar with the initials of a person, tinted by [tone].
class SupervisionInitialsAvatar extends StatelessWidget {
  const SupervisionInitialsAvatar({
    super.key,
    required this.name,
    this.size = 36,
    this.tone = SacTone.accent,
  });

  final String name;
  final double size;
  final SacTone tone;

  @override
  Widget build(BuildContext context) {
    final palette = SacTonePalette.of(context, tone);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: palette.container,
          shape: BoxShape.circle,
        ),
        child: Text(
          supervisionInitials(name),
          maxLines: 1,
          style: TextStyle(
            fontSize: SacFontSize.bodySmall,
            fontWeight: FontWeight.w700,
            color: palette.onContainer,
          ),
        ),
      ),
    );
  }
}

/// Logo of a club type (Aventureros, Conquistadores, Guías Mayores) at
/// [size]. A type with no logo shows its first letter on a grey tile, so the
/// section is never lost. Labeled with the type name.
class SupervisionClubTypeLogo extends StatelessWidget {
  const SupervisionClubTypeLogo({
    super.key,
    required this.typeName,
    this.size = 36,
  });

  final String typeName;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final asset = clubLogoAssetFromName(typeName);
    final Widget child;
    if (asset != null) {
      child = Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        // One side only: a logo keeps its own shape.
        cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
        excludeFromSemantics: true,
      );
    } else {
      final letter =
          typeName.trim().isEmpty ? '·' : typeName.trim()[0].toUpperCase();
      child = Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.surfaceVariant,
          borderRadius: BorderRadius.circular(AppTheme.radiusXS),
        ),
        child: Text(
          letter,
          style: TextStyle(
            fontSize: SacFontSize.bodyMedium,
            fontWeight: FontWeight.w700,
            color: c.textSecondary,
          ),
        ),
      );
    }
    return Semantics(
      image: true,
      label: typeName,
      excludeSemantics: true,
      child: SizedBox(width: size, height: size, child: child),
    );
  }
}

/// Date square of an event: the day big, the short month under it, on the
/// accent tint.
class SupervisionDateTile extends StatelessWidget {
  const SupervisionDateTile({super.key, required this.date});

  /// Null shows a neutral dash tile.
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final palette = SacTonePalette.of(context, SacTone.accent);
    final date = this.date;
    final locale = Localizations.maybeLocaleOf(context)?.toLanguageTag();
    final day = date == null ? '—' : '${date.day}';
    final month = date == null
        ? ''
        : intl.DateFormat.MMM(locale).format(date).replaceAll('.', '');
    return ExcludeSemantics(
      child: Container(
        // Grows with the text scale instead of clipping the month.
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: palette.container,
          borderRadius: BorderRadius.circular(AppTheme.radiusXS),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              day,
              style: TextStyle(
                fontSize: SacFontSize.titleMedium,
                height: 1.1,
                fontWeight: FontWeight.w700,
                color: palette.onContainer,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (month.isNotEmpty)
              Text(
                month.toUpperCase(),
                maxLines: 1,
                style: TextStyle(
                  fontSize: SacFontSize.labelSmall,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                  color: palette.onContainer,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
