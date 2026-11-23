import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Tokens of the credential. Only the section header has its own colors (the
/// identity of Aventureros, Conquistadores and Guías Mayores); the rest of
/// the screen uses `context.sac`.
class CredencialTokens {
  /// Status dot on the header pill.
  static const activeDot = Color(0xFF7CF0B4);
  static const suspendedDot = Color(0xFFFFB4AA);

  /// Icon over a blurred QR (always on the white QR tile) and text on the
  /// full-screen QR, which is white in light and dark mode.
  static const overlayIcon = Color(0xFF131316);
  static const mutedOnWhite = Color(0xFF6B7280);
  static const qrBorderOnWhite = Color(0xFFE3E5EA);

  /// "Valid · 09:01:22" pill on the full-screen QR.
  static const liveOnWhite = Color(0xFF1E6B55);
  static const liveContainer = Color(0xFFE0F5EF);

  // Radii
  static const rChip = 999.0;
  static const rImmersive = 24.0;
}

/// Club type of the credential.
// ignore: constant_identifier_names — AV/CQ/GM are domain acronyms, not regular identifiers.
enum SeccionCode { AV, CQ, GM }

/// Brand palette and logo of each club type.
class Sec {
  final SeccionCode code;
  final Color primary;
  final Color primaryDark;
  final String logo;

  const Sec({
    required this.code,
    required this.primary,
    required this.primaryDark,
    required this.logo,
  });

  /// Translated name of the club type.
  String get label {
    switch (code) {
      case SeccionCode.AV:
        return 'virtual_card.sections.av'.tr();
      case SeccionCode.CQ:
        return 'virtual_card.sections.cq'.tr();
      case SeccionCode.GM:
        return 'virtual_card.sections.gm'.tr();
    }
  }

  static const av = Sec(
    code: SeccionCode.AV,
    primary: Color(0xFF1F6FB5),
    primaryDark: Color(0xFF143F66),
    logo: 'assets/credencial/logo_aventureros.png',
  );

  static const cq = Sec(
    code: SeccionCode.CQ,
    primary: Color(0xFFC8102E),
    primaryDark: Color(0xFF7A0A1C),
    logo: 'assets/credencial/logo_conquistadores.png',
  );

  static const gm = Sec(
    code: SeccionCode.GM,
    primary: Color(0xFF0E7C3A),
    primaryDark: Color(0xFF054021),
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
