import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/sla_dashboard.dart';

/// Card compacto que muestra estadísticas SLA de un proceso.
///
/// Muestra pendientes, días promedio y vencidos de un [SlaStat].
class SlaStatCard extends StatelessWidget {
  final String title;
  final SlaStat stat;
  final Color accentColor;
  final List<dynamic> icon;

  const SlaStatCard({
    super.key,
    required this.title,
    required this.stat,
    required this.accentColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final hasOverdue = stat.overdue > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: c.shadow,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: icon,
                    size: 18,
                    color: accentColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Métricas ─────────────────────────────────────────────────────
          Row(
            children: [
              _Metric(
                label: 'Pendientes',
                value: stat.pending.toString(),
                valueColor: stat.pending > 0 ? accentColor : c.textSecondary,
              ),
              const SizedBox(width: 12),
              _Metric(
                label: 'Días prom.',
                value: stat.avgDays.toStringAsFixed(1),
                valueColor: c.textSecondary,
              ),
              const SizedBox(width: 12),
              _Metric(
                label: 'Vencidos',
                value: stat.overdue.toString(),
                valueColor: hasOverdue ? AppColors.error : c.textTertiary,
              ),
            ],
          ),

          // ── Alerta de vencidos ────────────────────────────────────────────
          if (hasOverdue) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedAlert02,
                    size: 13,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${stat.overdue} vencido${stat.overdue != 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _Metric({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: valueColor,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: c.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
