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

  // ────────── HELPERS ──────────
  /// Tonos de chip por nivel de severidad.
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
}

enum SeverityTone { rose, amber, mint, coral }

class ChipTone {
  final Color bg;
  final Color fg;
  final Color dot;
  const ChipTone({required this.bg, required this.fg, required this.dot});
}
