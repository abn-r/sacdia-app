import 'package:flutter/material.dart';
import 'medico_tokens.dart';

/// Chip con punto de color + etiqueta + sub-texto opcional.
/// Usado para alergias, enfermedades y similares.
class MedicalChip extends StatelessWidget {
  final String label;

  /// Sub-texto pequeño después del label (ej: severidad, "desde 2021").
  final String? sub;

  final SeverityTone tone;

  const MedicalChip({
    super.key,
    required this.label,
    required this.tone,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    final t = MedicoTokens.toneFor(tone);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: BorderRadius.circular(MedicoTokens.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: t.dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: t.fg,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(width: 6),
            Text(
              '· $sub',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: t.fg.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Layout de chips estilo `Wrap` con espacios consistentes.
class MedicalChipRow extends StatelessWidget {
  final List<Widget> children;
  const MedicalChipRow({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: children,
    );
  }
}
