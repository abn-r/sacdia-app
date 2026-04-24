import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/sla_dashboard.dart';

/// Muestra el pipeline de revisión como barras de progreso apiladas.
///
/// Recibe la lista de [PipelineStage] del dashboard SLA y las renderiza
/// proporcionalmente al total como barras horizontales con etiqueta y conteo.
class SlaPipelineChart extends StatelessWidget {
  final List<PipelineStage> stages;

  const SlaPipelineChart({super.key, required this.stages});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    if (stages.isEmpty) {
      return Center(
        child: Text(
          'coordinator.sla.pipeline.no_data'.tr(),
          style: TextStyle(fontSize: 13, color: c.textTertiary),
        ),
      );
    }

    final total = stages.fold<int>(0, (sum, s) => sum + s.count);

    final stageColors = [
      AppColors.primary,
      AppColors.accent,
      AppColors.info,
      AppColors.secondary,
      AppColors.secondaryDark,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'coordinator.sla.pipeline.title'.tr(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
        ),
        const SizedBox(height: 12),
        ...stages.asMap().entries.map((entry) {
          final index = entry.key;
          final stage = entry.value;
          final color = stageColors[index % stageColors.length];
          final fraction =
              total > 0 ? (stage.count / total).clamp(0.0, 1.0) : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      stage.stage,
                      style: TextStyle(
                        fontSize: 12,
                        color: c.textSecondary,
                      ),
                    ),
                    Text(
                      stage.count.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        // Background track
                        Container(
                          height: 8,
                          width: constraints.maxWidth,
                          decoration: BoxDecoration(
                            color: c.surfaceVariant,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        // Filled portion — AnimatedContainer is intentional:
                        // when the dashboard refreshes with new data the bar
                        // widths animate to their updated values, giving the
                        // user visible feedback that the counts changed.
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOut,
                          height: 8,
                          width: constraints.maxWidth * fraction,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

/// Gráfico de throughput semanal con barras simples.
class SlaThroughputChart extends StatelessWidget {
  final List<ThroughputPoint> data;

  const SlaThroughputChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    if (data.isEmpty) {
      return Center(
        child: Text(
          'coordinator.sla.pipeline.throughput_no_data'.tr(),
          style: TextStyle(fontSize: 13, color: c.textTertiary),
        ),
      );
    }

    // Show last 8 weeks max to avoid crowding
    final visible = data.length > 8 ? data.sublist(data.length - 8) : data;
    final maxCount = visible.fold<int>(
      0,
      (m, p) => p.approved + p.rejected > m ? p.approved + p.rejected : m,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'coordinator.sla.pipeline.throughput_title'.tr(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: visible.map((point) {
              final total = point.approved + point.rejected;
              final barFraction =
                  maxCount > 0 ? (total / maxCount).clamp(0.0, 1.0) : 0.0;
              final approvedFraction =
                  total > 0 ? (point.approved / total) : 0.0;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Stacked bar
                      SizedBox(
                        height: 80 * barFraction,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: Column(
                            children: [
                              // Approved (green, bottom)
                              Expanded(
                                flex: (approvedFraction * 100).round(),
                                child: Container(
                                  color: AppColors.secondary,
                                ),
                              ),
                              // Rejected (red, top)
                              Expanded(
                                flex:
                                    ((1 - approvedFraction) * 100).round(),
                                child: Container(
                                  color: AppColors.error.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _shortWeek(point.week),
                        style: TextStyle(
                          fontSize: 8,
                          color: c.textTertiary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        // Legend
        Row(
          children: [
            _LegendDot(
              color: AppColors.secondary,
              label: 'coordinator.sla.pipeline.legend_approved'.tr(),
            ),
            const SizedBox(width: 12),
            _LegendDot(
              color: AppColors.error,
              label: 'coordinator.sla.pipeline.legend_rejected'.tr(),
            ),
          ],
        ),
      ],
    );
  }

  /// Trunca la cadena de semana para mostrarla en el eje.
  String _shortWeek(String week) {
    // Handle ISO week format "2024-W12" → "W12", or just take last 3 chars
    if (week.contains('-W')) {
      return week.split('-W').last;
    }
    return week.length > 5 ? week.substring(week.length - 5) : week;
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: c.textTertiary),
        ),
      ],
    );
  }
}
