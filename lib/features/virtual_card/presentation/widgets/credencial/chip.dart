import 'package:flutter/material.dart';

import 'credencial_tokens.dart';

/// Chip translúcido sobre la tarjeta inmersiva.
/// Si [accent] está presente, usa fondo sólido y texto oscuro (p.ej. honores).
class CredChip extends StatelessWidget {
  final String label;
  final Color? accent;
  const CredChip({super.key, required this.label, this.accent});

  @override
  Widget build(BuildContext context) {
    final hasAccent = accent != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: hasAccent ? accent : Colors.white.withAlpha(0x2E), // 0x2E ≈ 18%
        borderRadius: BorderRadius.circular(CredencialTokens.rChip),
        border: Border.all(color: Colors.white.withAlpha(0x38)), // 0x38 ≈ 22%
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: hasAccent ? const Color(0xFF0F1115) : Colors.white,
        ),
      ),
    );
  }
}
