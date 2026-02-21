import 'package:flutter/material.dart';
import 'package:sacdia_app/core/animations/animated_counter.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';

/// Fila de 3 mini cards de estadísticas - Estilo "Scout Vibrante"
///
/// Especialidades (amber), Actividades (indigo), Asistencia (emerald).
/// Números animan contando hacia arriba al montarse (AnimatedCounter).
/// Labels have overflow guard — maxLines: 2.
class QuickStatsCard extends StatelessWidget {
  final int honorsCompleted;
  final int honorsInProgress;

  const QuickStatsCard({
    super.key,
    required this.honorsCompleted,
    required this.honorsInProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniStatCard(
            icon: HugeIcons.strokeRoundedMedal01,
            color: AppColors.accent,
            bgColor: AppColors.accentLight,
            value: honorsCompleted,
            label: 'Completadas',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStatCard(
            icon: HugeIcons.strokeRoundedClock01,
            color: AppColors.primary,
            bgColor: AppColors.primaryLight,
            value: honorsInProgress,
            label: 'En progreso',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStatCard(
            icon: HugeIcons.strokeRoundedCalendarAdd01,
            color: AppColors.secondary,
            bgColor: AppColors.secondaryLight,
            value: null, // attendance not yet implemented
            label: 'Asistencia',
          ),
        ),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final dynamic icon;
  final Color color;
  final Color bgColor;
  final int? value; // null = show dash
  final String label;

  const _MiniStatCard({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SacCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: buildIcon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          // Animated counter for numeric values, dash for unavailable
          if (value != null)
            AnimatedCounter(
              value: value!,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            )
          else
            Text(
              '—',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          const SizedBox(height: 2),
          // Label — overflow guard for narrow cards
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.lightTextSecondary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
