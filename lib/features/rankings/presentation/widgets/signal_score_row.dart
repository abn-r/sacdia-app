import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../core/widgets/sac_card.dart';

/// Fila con tres tarjetas de señal: Clase, Investidura y Camporees.
///
/// Cada tarjeta muestra el icono, el puntaje (o "—" si es null) y la etiqueta.
/// Sin onTap — solo display (OD-1 bloqueado).
class SignalScoreRow extends StatelessWidget {
  final double? classScore;
  final double? investitureScore;
  final double? camporeeScore;

  const SignalScoreRow({
    super.key,
    this.classScore,
    this.investitureScore,
    this.camporeeScore,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: _SignalScoreCard(
              icon: HugeIcons.strokeRoundedBook01,
              score: classScore,
              label: 'Clase',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SignalScoreCard(
              icon: HugeIcons.strokeRoundedMedal01,
              score: investitureScore,
              label: 'Investidura',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SignalScoreCard(
              icon: HugeIcons.strokeRoundedCampfire,
              score: camporeeScore,
              label: 'Camporees',
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta individual de señal. Privada a este archivo.
class _SignalScoreCard extends StatelessWidget {
  final HugeIconData icon;
  final double? score;
  final String label;

  const _SignalScoreCard({
    required this.icon,
    this.score,
    required this.label,
  });

  /// Formatea el puntaje: 1 decimal cuando fraccionario != 0.
  String _formatScore(double value) {
    if (value == value.truncateToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final hasScore = score != null;
    final iconColor = hasScore ? AppColors.primary : c.textTertiary;

    return SacCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 80),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(icon: icon, size: 24, color: iconColor),
            const SizedBox(height: 6),
            Text(
              hasScore ? _formatScore(score!) : '—',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: hasScore ? c.text : c.textTertiary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: c.textTertiary,
                  ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
