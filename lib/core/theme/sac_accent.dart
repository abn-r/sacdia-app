import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Familia del acento en el selector de Configuración.
enum AccentFamily { brand, club, classLevel }

/// Club al que pertenece un acento de clase o de tipo.
enum AccentClub { aventureros, conquistadores, guiasMayores }

/// Acento de sistema. El valor por defecto es el azul del icono.
///
/// [AppColors.primary] sigue siendo el coral fijo (también el rojo de
/// Conquistadores). Los controles del sistema leen este acento, no ese
/// constante.
@immutable
class SacAccent extends ThemeExtension<SacAccent> {
  const SacAccent({
    required this.id,
    required this.labelKey,
    required this.family,
    required this.color,
    required this.light,
    required this.dark,
    required this.surface,
    required this.onColor,
    this.club,
  });

  final String id;
  final String labelKey;
  final AccentFamily family;
  final AccentClub? club;
  final Color color;
  final Color light;
  final Color dark;
  final Color surface;
  final Color onColor;

  static const logoBlue = SacAccent(
    id: 'brand.blue',
    labelKey: 'profile.settings.accent_blue',
    family: AccentFamily.brand,
    color: AppColors.loginBrandBlue,
    light: Color(0xFFD8EBFD),
    dark: AppColors.loginBrandBlueDark,
    surface: Color(0xFFEBF5FE),
    onColor: Colors.white,
  );

  static const coral = SacAccent(
    id: 'brand.coral',
    labelKey: 'profile.settings.accent_coral',
    family: AccentFamily.brand,
    color: AppColors.primary,
    light: AppColors.primaryLight,
    dark: AppColors.primaryDark,
    surface: AppColors.primarySurface,
    onColor: Colors.white,
  );

  static final aventureros = SacAccent.derived(
    id: 'club.aventureros',
    labelKey: 'welcome_carousel.ministry_adventurers',
    family: AccentFamily.club,
    club: AccentClub.aventureros,
    color: AppColors.info,
  );

  static const conquistadores = SacAccent(
    id: 'club.conquistadores',
    labelKey: 'welcome_carousel.ministry_pathfinders',
    family: AccentFamily.club,
    club: AccentClub.conquistadores,
    color: AppColors.primary,
    light: AppColors.primaryLight,
    dark: AppColors.primaryDark,
    surface: AppColors.primarySurface,
    onColor: Colors.white,
  );

  static const guiasMayores = SacAccent(
    id: 'club.guias',
    labelKey: 'welcome_carousel.ministry_master_guides',
    family: AccentFamily.club,
    club: AccentClub.guiasMayores,
    color: AppColors.secondary,
    light: AppColors.secondaryLight,
    dark: AppColors.secondaryDark,
    surface: Color(0xFFF3FBF8),
    onColor: Color(0xFF13211C),
  );

  static final List<SacAccent> catalog = [
    logoBlue,
    coral,
    aventureros,
    conquistadores,
    guiasMayores,
    ..._classAccents,
  ];

  static SacAccent byId(String? id) {
    if (id == null || id.isEmpty) return logoBlue;
    for (final accent in catalog) {
      if (accent.id == id) return accent;
    }
    return logoBlue;
  }

  static SacAccent of(BuildContext context) {
    return Theme.of(context).extension<SacAccent>() ?? logoBlue;
  }

  /// En oscuro, un tono demasiado oscuro (navy de Guía Mayor, por ejemplo)
  /// se aclara para seguir leyéndose sobre la superficie.
  SacAccent forBrightness(Brightness brightness) {
    if (brightness != Brightness.dark) return this;
    final hsl = HSLColor.fromColor(color);
    if (hsl.lightness >= 0.45) return this;
    final lifted = hsl
        .withLightness(0.55)
        .withSaturation(hsl.saturation.clamp(0.35, 1))
        .toColor();
    return _retinted(lifted);
  }

  /// Alto contraste: empuja el tono hasta 4.5:1 contra el fondo, sin
  /// cambiar de familia.
  SacAccent forHighContrast(Brightness brightness) {
    final against = brightness == Brightness.dark ? Colors.black : Colors.white;
    final darken = brightness != Brightness.dark;
    var hsl = HSLColor.fromColor(color);
    for (var i = 0; i < 24; i++) {
      final next = hsl.toColor();
      if (_contrast(next, against) >= 4.5) return _retinted(next);
      final step = darken ? -0.03 : 0.04;
      hsl = hsl.withLightness((hsl.lightness + step).clamp(0.12, 0.88));
    }
    return _retinted(hsl.toColor());
  }

  factory SacAccent.derived({
    required String id,
    required String labelKey,
    required Color color,
    required AccentFamily family,
    AccentClub? club,
  }) {
    return SacAccent(
      id: id,
      labelKey: labelKey,
      family: family,
      club: club,
      color: color,
      light: _tint(color, 0.16),
      dark: _shade(color),
      surface: _tint(color, 0.08),
      onColor: _onColor(color),
    );
  }

  SacAccent _retinted(Color next) {
    return SacAccent(
      id: id,
      labelKey: labelKey,
      family: family,
      club: club,
      color: next,
      light: _tint(next, 0.18),
      dark: _shade(next),
      surface: _tint(next, 0.1),
      onColor: _onColor(next),
    );
  }

  @override
  SacAccent copyWith({
    String? id,
    String? labelKey,
    AccentFamily? family,
    AccentClub? club,
    Color? color,
    Color? light,
    Color? dark,
    Color? surface,
    Color? onColor,
  }) {
    return SacAccent(
      id: id ?? this.id,
      labelKey: labelKey ?? this.labelKey,
      family: family ?? this.family,
      club: club ?? this.club,
      color: color ?? this.color,
      light: light ?? this.light,
      dark: dark ?? this.dark,
      surface: surface ?? this.surface,
      onColor: onColor ?? this.onColor,
    );
  }

  @override
  SacAccent lerp(ThemeExtension<SacAccent>? other, double t) {
    if (other is! SacAccent) return this;
    return SacAccent(
      id: t < 0.5 ? id : other.id,
      labelKey: t < 0.5 ? labelKey : other.labelKey,
      family: t < 0.5 ? family : other.family,
      club: t < 0.5 ? club : other.club,
      color: Color.lerp(color, other.color, t) ?? color,
      light: Color.lerp(light, other.light, t) ?? light,
      dark: Color.lerp(dark, other.dark, t) ?? dark,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      onColor: Color.lerp(onColor, other.onColor, t) ?? onColor,
    );
  }

  @override
  bool operator ==(Object other) => other is SacAccent && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

final List<SacAccent> _classAccents = [
  _class('class.lambs', 'domain.classes.lambs', AppColors.colorCorderitos,
      AccentClub.aventureros),
  _class('class.eager_beavers', 'domain.classes.eager_beavers',
      AppColors.colorCastores, AccentClub.aventureros),
  _class('class.busy_bees', 'domain.classes.busy_bees', AppColors.colorAbejas,
      AccentClub.aventureros),
  _class('class.sunbeams', 'domain.classes.sunbeams', AppColors.colorRayos,
      AccentClub.aventureros),
  _class('class.builders', 'domain.classes.builders',
      AppColors.colorConstructores, AccentClub.aventureros),
  _class('class.helping_hands', 'domain.classes.helping_hands',
      AppColors.colorManos, AccentClub.aventureros),
  _class('class.friend', 'domain.classes.friend', AppColors.colorAmigo,
      AccentClub.conquistadores),
  _class('class.companion', 'domain.classes.companion',
      AppColors.colorCompanero, AccentClub.conquistadores),
  _class('class.explorer', 'domain.classes.explorer', AppColors.colorExplorador,
      AccentClub.conquistadores),
  _class('class.pioneer', 'domain.classes.pioneer', AppColors.colorOrientador,
      AccentClub.conquistadores),
  _class('class.voyager', 'domain.classes.voyager', AppColors.colorViajero,
      AccentClub.conquistadores),
  _class('class.guide', 'domain.classes.guide', AppColors.colorGuia,
      AccentClub.conquistadores),
  _class('class.master_guide', 'domain.classes.master_guide',
      AppColors.colorGuiaMayor, AccentClub.guiasMayores),
  _class('class.advanced_guide', 'domain.classes.advanced_guide',
      AppColors.colorGuiaAvanzado, AccentClub.guiasMayores),
  _class('class.instructor_guide', 'domain.classes.instructor_guide',
      AppColors.colorGuiaInstructor, AccentClub.guiasMayores),
];

SacAccent _class(String id, String labelKey, Color color, AccentClub club) {
  return SacAccent.derived(
    id: id,
    labelKey: labelKey,
    family: AccentFamily.classLevel,
    club: club,
    color: color,
  );
}

Color _tint(Color color, double amount) {
  return Color.alphaBlend(color.withValues(alpha: amount), Colors.white);
}

Color _shade(Color color) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness - 0.12).clamp(0.15, 0.82)).toColor();
}

Color _onColor(Color color) {
  return _contrast(color, Colors.white) >= 3
      ? Colors.white
      : const Color(0xFF131316);
}

double _contrast(Color a, Color b) {
  final lighter = a.computeLuminance();
  final darker = b.computeLuminance();
  final top = lighter > darker ? lighter : darker;
  final bottom = lighter > darker ? darker : lighter;
  return (top + 0.05) / (bottom + 0.05);
}
