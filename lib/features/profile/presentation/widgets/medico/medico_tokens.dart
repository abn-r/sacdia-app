import 'package:flutter/material.dart';

/// Feature-scoped tokens for Información Médica (Variante A).
///
/// Coral and ink tokens duplicate `AppColors` values intentionally
/// (feature-scoped per ADR-1). They are kept here so this screen's
/// palette can evolve independently from the global theme. If the team
/// later adopts the full palette app-wide, migrate `MedicoTokens.coralN`
/// → `AppColors.coralN` mechanically.
///
/// Mint, amber, rose, and lavender scales are net-new and remain
/// medical-screen-scoped.
class MedicoTokens {
  MedicoTokens._();

  // ────────── BRAND / SEMÁNTICA ──────────
  static const coral50 = Color(0xFFFFF1EE);
  static const coral100 = Color(0xFFFFE3DD);
  static const coral200 = Color(0xFFFFC9BE);
  static const coral300 = Color(0xFFFFA493);
  static const coral500 = Color(0xFFEF6B5C); // primario
  static const coral600 = Color(0xFFDD5A4B);
  static const coral700 = Color(0xFFB8453A);

  static const mint50 = Color(0xFFE8F5EE);
  static const mint100 = Color(0xFFD7EFE2);
  static const mint500 = Color(0xFF4FB37C);
  static const mintInk = Color(0xFF2C7A52); // texto sobre mint50
  static const mintInkSoft = Color(0xFF5A8A6E);

  static const amber50 = Color(0xFFFCF1DC);
  static const amber100 = Color(0xFFFBE7C2);
  static const amber500 = Color(0xFFC99036);
  static const amberInk = Color(0xFF8B6020);

  static const lavender100 = Color(0xFFDCD5EE);
  static const lavender500 = Color(0xFF6B59A8);

  static const rose50 = Color(0xFFFDE9EE);
  static const rose500 = Color(0xFFD14B66);
  static const roseInk = Color(0xFF9B2D49);

  // ────────── NEUTRALES ──────────
  static const ink900 = Color(0xFF131316);
  static const ink800 = Color(0xFF20232A);
  static const ink700 = Color(0xFF2C313B);
  static const ink600 = Color(0xFF4B5260);
  static const ink500 = Color(0xFF6B7280);
  static const ink400 = Color(0xFF9AA0AB);
  static const ink300 = Color(0xFFC7CBD2);
  static const ink200 = Color(0xFFE3E5EA);
  static const ink150 = Color(0xFFECEEF2);
  static const ink100 = Color(0xFFF2F4F7);
  static const ink50 = Color(0xFFF7F8FA);
  static const paper = Color(0xFFFFFFFF);
  static const canvas = Color(0xFFFAFAFB);

  // ────────── ESPACIADO (4pt) ──────────
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 20.0;
  static const s6 = 24.0;
  static const s8 = 32.0;

  // ────────── RADIOS ──────────
  static const rField = 10.0;
  static const rChipSmall = 12.0;
  static const rCard = 18.0;
  static const rHero = 22.0;
  static const rPill = 999.0;

  // ────────── ELEVACIÓN ──────────
  static const shadowCard = [
    BoxShadow(color: Color(0x0A111827), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const shadowHero = [
    BoxShadow(
      color: Color(0x66EF6B5C),
      blurRadius: 28,
      offset: Offset(0, 10),
      spreadRadius: -10,
    ),
  ];

  // ────────── ANCHOS DE ICONOS DE SECCIÓN ──────────
  static const sectionIconBox = 38.0;
  static const sectionIconRadius = 11.0;

  // ────────── SOS-SPECIFIC TOKENS ──────────
  static const sosCanvas = Color(0xFFFFF7F5);
  static const sosInkOnCoral = Color(0xFFFFFFFF);
  static const sosCritical = coral600; // semantic alias para coral600

  // ────────── HELPERS ──────────
  /// Tonos de chip por nivel de severidad (solo light).
  ///
  /// Prefiere [MedicoPalette.toneFor] vía `MedicoTokens.of(context)` para
  /// soporte de tema oscuro.
  static ChipTone toneFor(SeverityTone t) {
    switch (t) {
      case SeverityTone.rose:
        return const ChipTone(bg: rose50, fg: roseInk, dot: rose500);
      case SeverityTone.amber:
        return const ChipTone(bg: amber50, fg: amberInk, dot: amber500);
      case SeverityTone.mint:
        return const ChipTone(bg: mint50, fg: mintInk, dot: mint500);
      case SeverityTone.coral:
        return const ChipTone(bg: coral50, fg: coral700, dot: coral500);
    }
  }

  /// Paleta semántica resuelta según el [Brightness] del tema actual.
  static MedicoPalette of(BuildContext context) =>
      MedicoPalette(Theme.of(context).brightness);
}

/// Paleta semántica de Información Médica, resuelta por brillo del tema.
///
/// Sigue el patrón de `SacColors` (`context.sac`): los acentos de marca
/// (coral, mint, amber, rose, lavender) mantienen su valor en ambos modos;
/// las superficies tintadas y los neutrales cambian para mantener contraste
/// sobre fondos oscuros. Los neutrales dark se alinean con `AppColors.dark*`.
class MedicoPalette {
  final Brightness _brightness;

  const MedicoPalette(this._brightness);

  bool get isDark => _brightness == Brightness.dark;

  // ────────── SUPERFICIES ──────────
  /// Fondo de pantalla.
  Color get canvas => isDark ? const Color(0xFF000000) : MedicoTokens.canvas;

  /// Fondo de tarjetas y app bar.
  Color get paper => isDark ? const Color(0xFF1A1A1A) : MedicoTokens.paper;

  /// Fondo de filas internas (contactos, empty hints).
  Color get tileBg => isDark ? const Color(0xFF252525) : MedicoTokens.ink50;

  /// Fondo de controles neutros (botón atrás, botón SMS).
  Color get controlBg => isDark ? const Color(0xFF2E2E2E) : MedicoTokens.ink100;

  /// Borde de tarjetas / separador de app bar.
  Color get border => isDark ? const Color(0xFF303030) : MedicoTokens.ink150;

  // ────────── TEXTO E ICONOS NEUTROS ──────────
  Color get textPrimary =>
      isDark ? const Color(0xFFF2F2F2) : MedicoTokens.ink900;

  Color get textSecondary =>
      isDark ? const Color(0xFF9A9A9A) : MedicoTokens.ink500;

  /// Icono sobre [controlBg] (ej. SMS).
  Color get iconMuted => isDark ? const Color(0xFFB8B8B8) : MedicoTokens.ink600;

  /// Icono fuerte sobre [controlBg] (ej. flecha atrás).
  Color get iconStrong =>
      isDark ? const Color(0xFFF2F2F2) : MedicoTokens.ink800;

  // ────────── ACENTOS TINTADOS ──────────
  // *Soft: fondo del badge/chip. *Fg: icono/texto sobre ese fondo.

  Color get coralSoft =>
      isDark ? const Color(0x33EF6B5C) : MedicoTokens.coral100;
  Color get coralFg => isDark ? MedicoTokens.coral300 : MedicoTokens.coral600;

  /// Acción coral ("Editar", CTA). Contrasta bien en ambos modos.
  Color get coralAction => MedicoTokens.coral500;

  Color get roseSoft => isDark ? const Color(0x33D14B66) : MedicoTokens.rose50;
  Color get roseFg => isDark ? const Color(0xFFE8788E) : MedicoTokens.rose500;
  Color get roseInk => isDark ? const Color(0xFFF4A7B8) : MedicoTokens.roseInk;

  Color get amberSoft =>
      isDark ? const Color(0x33C99036) : MedicoTokens.amber50;
  Color get amberFg => isDark ? const Color(0xFFE0AA55) : MedicoTokens.amber500;
  Color get amberInk =>
      isDark ? const Color(0xFFF0C674) : MedicoTokens.amberInk;

  Color get mintSoft => isDark ? const Color(0x334FB37C) : MedicoTokens.mint50;
  Color get mintFg => isDark ? const Color(0xFF6CC994) : MedicoTokens.mint500;
  Color get mintInk => isDark ? const Color(0xFFA6E3C2) : MedicoTokens.mintInk;
  Color get mintInkSoft =>
      isDark ? const Color(0xFF7FC9A2) : MedicoTokens.mintInkSoft;

  Color get lavenderSoft =>
      isDark ? const Color(0x336B59A8) : MedicoTokens.lavender100;
  Color get lavenderFg =>
      isDark ? const Color(0xFFA79BDA) : MedicoTokens.lavender500;

  // ────────── ELEVACIÓN ──────────
  /// Sombra de tarjeta; en dark el borde ya delimita, sin sombra.
  List<BoxShadow> get cardShadow =>
      isDark ? const [] : MedicoTokens.shadowCard;

  // ────────── HELPERS ──────────
  /// Tonos de chip por nivel de severidad, adaptados al tema.
  ChipTone toneFor(SeverityTone t) {
    switch (t) {
      case SeverityTone.rose:
        return ChipTone(bg: roseSoft, fg: roseInk, dot: roseFg);
      case SeverityTone.amber:
        return ChipTone(bg: amberSoft, fg: amberInk, dot: amberFg);
      case SeverityTone.mint:
        return ChipTone(bg: mintSoft, fg: mintInk, dot: mintFg);
      case SeverityTone.coral:
        return ChipTone(
          bg: isDark ? coralSoft : MedicoTokens.coral50,
          fg: isDark ? MedicoTokens.coral300 : MedicoTokens.coral700,
          dot: MedicoTokens.coral500,
        );
    }
  }
}

enum SeverityTone { rose, amber, mint, coral }

class ChipTone {
  final Color bg;
  final Color fg;
  final Color dot;
  const ChipTone({required this.bg, required this.fg, required this.dot});
}
