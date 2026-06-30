import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Canonical set of club organization types recognised by SACDIA.
///
/// This is the single source of truth for the club-type → accent-color mapping.
/// Any feature that needs to resolve a color from a club type name must go
/// through [clubTypeFromName] + [ClubColorX.color] rather than duplicating the
/// string-matching logic.
enum ClubType {
  conquistadores,
  aventureros,
  guiasMayores,
}

/// Extension that binds each [ClubType] to its canonical accent color.
///
/// Colors are pulled directly from [AppColors] constants so both sources stay
/// in sync automatically — changing a constant here propagates everywhere.
extension ClubColorX on ClubType {
  Color get color {
    switch (this) {
      case ClubType.conquistadores:
        return AppColors.primary; // SACDIA Red
      case ClubType.aventureros:
        return AppColors.info; // SACDIA Blue
      case ClubType.guiasMayores:
        return AppColors.secondary; // SACDIA Green
    }
  }

  String get logoAsset {
    switch (this) {
      case ClubType.conquistadores:
        return 'assets/img/logo_conquistadores_color.png';
      case ClubType.aventureros:
        return 'assets/img/logo_aventureros_color.png';
      case ClubType.guiasMayores:
        return 'assets/img/logo-guias-mayores.png';
    }
  }
}

/// Resolves a raw club-type string (as it arrives from the API / grants) to a
/// [ClubType] enum value.
///
/// Matching is:
/// - case-insensitive
/// - whitespace-trimmed
/// - substring-based (mirrors the original [_getClubColor] logic)
///
/// Returns `null` for unknown / empty inputs so call sites can apply their own
/// fallback instead of silently receiving a wrong color.
ClubType? clubTypeFromName(String? name) {
  if (name == null) return null;
  final lower = name.trim().toLowerCase();
  if (lower.contains('conquistador')) return ClubType.conquistadores;
  if (lower.contains('aventurer')) return ClubType.aventureros;
  if (lower.contains('guía') || lower.contains('guia')) {
    return ClubType.guiasMayores;
  }
  return null;
}

/// Convenience helper: resolves [name] to a [Color], falling back to
/// [AppColors.primary] for unknown inputs — identical behaviour to the
/// original private `_getClubColor` method in [ClubInfoCard].
Color clubColorFromName(String? name) =>
    clubTypeFromName(name)?.color ?? AppColors.primary;

String? clubLogoAssetFromName(String? name) =>
    clubTypeFromName(name)?.logoAsset;

/// Resolves the canonical badge background/foreground colors for a club type.
///
/// This mirrors the section switcher visual language:
/// - Conquistadores → red
/// - Aventureros → blue
/// - Guías Mayores → green
///
/// Unknown values intentionally fall back to Conquistadores/SACDIA primary
/// because that was the previous default for generic club-type badges.
(Color background, Color foreground) clubBadgeColorsFromName(String? name) {
  switch (clubTypeFromName(name)) {
    case ClubType.conquistadores:
      return (AppColors.primaryLight, AppColors.primaryDark);
    case ClubType.aventureros:
      return (const Color(0xFFE0F0FA), const Color(0xFF1A6B9C));
    case ClubType.guiasMayores:
      return (AppColors.secondaryLight, AppColors.secondaryDark);
    case null:
      return (AppColors.primaryLight, AppColors.primaryDark);
  }
}
