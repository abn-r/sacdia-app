import 'package:flutter/material.dart';

/// Tokens for the virtual card screen and QR tile.
class VirtualCardTokens {
  const VirtualCardTokens._();

  /// Tint over a credential that is inactive.
  static const Color inactiveOverlay = Color(0x33C53D3D);

  /// Dark navy pill background used for floating hints.
  static const Color hintPill = Color(0xEE0F1B2D);

  /// Border of the QR tile, which is always white.
  static const Color qrTileBorder = Color(0xFFE5E8EE);

  /// Soft navy shadow under the QR tile.
  static const Color qrShadow = Color(0x220F1B2D);
}
