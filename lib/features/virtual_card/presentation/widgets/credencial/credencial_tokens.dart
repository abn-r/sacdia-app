import 'package:flutter/material.dart';

/// Design tokens — Credencial Digital SACDIA (Variante B).
/// Mantén los colores y radios sincronizados con SPEC.md.
class CredencialTokens {
  // Marca SACDIA
  static const accent = Color(0xFFEF6B5C);

  // Neutrales — light
  static const bgLight = Color(0xFFF4F5F8);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const borderLight = Color(0xFFECEEF2);
  static const textPrimaryLight = Color(0xFF0F1115);
  static const textSecondaryLight = Color(0xFF6B7280);
  static const textTertiaryLight = Color(0xFF9AA0AB);

  // Neutrales — dark
  static const bgDark = Color(0xFF0E1014);
  static const surfaceDark = Color(0xFF1A1C22);
  static const borderDark = Color(0x14FFFFFF);
  static const textPrimaryDark = Color(0xFFF4F4F6);
  static const textSecondaryDark = Color(0x80FFFFFF);
  static const textTertiaryDark = Color(0x55FFFFFF);

  // Estado
  static const success = Color(0xFF0E7C3A);
  static const danger = Color(0xFFC8102E);
  static const dangerSoft = Color(0xFFFBE9EC);

  // Espaciado
  static const s1 = 4.0;
  static const s2 = 6.0;
  static const s3 = 8.0;
  static const s4 = 10.0;
  static const s5 = 12.0;
  static const s6 = 14.0;
  static const s7 = 16.0;
  static const s8 = 18.0;
  static const s9 = 20.0;
  static const s10 = 24.0;

  // Radios
  static const rChip = 999.0;
  static const rField = 8.0;
  static const rPill = 12.0;
  static const rCard = 14.0;
  static const rImmersive = 24.0;
}

/// Paleta por sección.
// ignore: constant_identifier_names — AV/CQ/GM are domain acronyms, not regular identifiers.
enum SeccionCode { AV, CQ, GM }

class Sec {
  final SeccionCode code;
  final String name;
  final String motto;
  final Color primary;
  final Color primaryDark;
  final Color accent;
  final Color soft;
  final String logo;

  const Sec({
    required this.code,
    required this.name,
    required this.motto,
    required this.primary,
    required this.primaryDark,
    required this.accent,
    required this.soft,
    required this.logo,
  });

  static const av = Sec(
    code: SeccionCode.AV,
    name: 'Aventureros',
    motto: 'Por amor a Jesús haré lo mejor',
    primary: Color(0xFF1F6FB5),
    primaryDark: Color(0xFF143F66),
    accent: Color(0xFFFFC72C),
    soft: Color(0xFFE8F1FA),
    logo: 'assets/credencial/logo_aventureros.png',
  );

  static const cq = Sec(
    code: SeccionCode.CQ,
    name: 'Conquistadores',
    motto: 'El amor de Cristo me motiva',
    primary: Color(0xFFC8102E),
    primaryDark: Color(0xFF7A0A1C),
    accent: Color(0xFFFFD400),
    soft: Color(0xFFFBE9EC),
    logo: 'assets/credencial/logo_conquistadores.png',
  );

  static const gm = Sec(
    code: SeccionCode.GM,
    name: 'Guías Mayores',
    motto: 'El amor de Cristo me motiva',
    primary: Color(0xFF0E7C3A),
    primaryDark: Color(0xFF054021),
    accent: Color(0xFFF2C94C),
    soft: Color(0xFFE5F4EB),
    logo: 'assets/credencial/logo_guias_mayores.png',
  );

  static Sec of(SeccionCode c) {
    switch (c) {
      case SeccionCode.AV:
        return av;
      case SeccionCode.CQ:
        return cq;
      case SeccionCode.GM:
        return gm;
    }
  }
}
