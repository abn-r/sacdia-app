import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/animated_counter.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';

/// Estadísticas principales del dashboard con foco accionable.
///
/// Diseño basado en la opción 2: muestra la misión actual del usuario, usando
/// solo datos reales del summary: especialidades completadas, especialidades en
/// curso y progreso de clase.
class QuickStatsCard extends StatelessWidget {
  final int honorsCompleted;
  final int honorsInProgress;
  final double classProgress;

  const QuickStatsCard({
    super.key,
    required this.honorsCompleted,
    required this.honorsInProgress,
    required this.classProgress,
  });

  int get _progressPercent => (classProgress.clamp(0.0, 1.0) * 100).round();

  @override
  Widget build(BuildContext context) {
    return _MissionStatsCard(
      honorsCompleted: honorsCompleted,
      honorsInProgress: honorsInProgress,
      progressPercent: _progressPercent,
    );
  }
}

class _MissionStatsCard extends StatelessWidget {
  final int honorsCompleted;
  final int honorsInProgress;
  final int progressPercent;

  const _MissionStatsCard({
    required this.honorsCompleted,
    required this.honorsInProgress,
    required this.progressPercent,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBackground = isDark ? c.surfaceVariant : c.surface;
    final cardBorder =
        isDark ? c.border : AppColors.primary.withValues(alpha: 0.12);
    final iconBackground = isDark
        ? AppColors.accent.withValues(alpha: 0.16)
        : AppColors.accentLight;
    final helperColor = isDark
        ? c.textTertiary
        : AppColors.lightTextSecondary.withValues(alpha: 0.86);

    return SacCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: cardBackground,
      borderColor: cardBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: buildIcon(
                  HugeIcons.strokeRoundedTarget02,
                  color: isDark ? AppColors.accent : AppColors.accentDark,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Misión actual',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: c.text,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Seguí empujando lo que está en curso.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: c.textSecondary,
                            height: 1.35,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _MissionPrimaryStat(
            value: honorsInProgress,
            title: 'especialidades abiertas',
            subtitle: honorsInProgress == 0
                ? 'No tenés pendientes por ahora.'
                : 'Elegí una y cerrá el próximo paso.',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MissionMiniStat(
                  icon: HugeIcons.strokeRoundedMedal01,
                  value: honorsCompleted,
                  label: 'cerradas',
                  color: c.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MissionMiniStat(
                  icon: HugeIcons.strokeRoundedSchool01,
                  value: progressPercent,
                  suffix: '%',
                  label: 'clase',
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            honorsInProgress == 0
                ? 'Buen trabajo. Ahora puedes revisar tu próxima clase o nuevos honores.'
                : 'Tu foco está claro: avanzá una especialidad pendiente a la vez.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: helperColor,
                  fontSize: 11,
                  height: 1.3,
                ),
          ),
        ],
      ),
    );
  }
}

class _MissionPrimaryStat extends StatelessWidget {
  final int value;
  final String title;
  final String subtitle;

  const _MissionPrimaryStat({
    required this.value,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelBackground = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : AppColors.accentLight.withValues(alpha: 0.62);
    final panelBorder = isDark
        ? Colors.white.withValues(alpha: 0.09)
        : AppColors.accent.withValues(alpha: 0.22);
    final valueColor = isDark ? AppColors.accent : AppColors.accentDark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: panelBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: panelBorder),
      ),
      child: Row(
        children: [
          AnimatedCounter(
            value: value,
            style: TextStyle(
              color: valueColor,
              fontSize: 38,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: c.text,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: c.textSecondary,
                        height: 1.3,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionMiniStat extends StatelessWidget {
  final dynamic icon;
  final int value;
  final String suffix;
  final String label;
  final Color color;

  const _MissionMiniStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDark ? Colors.white.withValues(alpha: 0.05) : c.surfaceVariant;
    final border =
        isDark ? Colors.white.withValues(alpha: 0.06) : c.borderLight;
    final iconBackground = color.withValues(alpha: isDark ? 0.16 : 0.10);

    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: buildIcon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          AnimatedCounter(
            value: value,
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (suffix.isNotEmpty)
            Text(
              suffix,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
