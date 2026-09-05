import 'package:flutter/material.dart';
import 'medico_tokens.dart';

/// Widget de estado vacío para secciones sin datos.
///
/// Muestra un label en itálica y, opcionalmente, un CTA coral
/// que dispara [onAction].
class EmptyHint extends StatelessWidget {
  final String label;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyHint({
    super.key,
    required this.label,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final m = MedicoTokens.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: m.tileBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: m.textSecondary,
              fontSize: 13,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: TextStyle(
                  color: m.coralAction,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
