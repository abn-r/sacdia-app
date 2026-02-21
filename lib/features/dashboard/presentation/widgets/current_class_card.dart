import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_progress_ring.dart';

/// Card de clase actual con SacProgressRing - Estilo "Scout Vibrante"
///
/// Grande SacProgressRing centrado (Apple Health style),
/// nombre de clase, motivational text.
/// Ring size adapts via LayoutBuilder — no fixed 140px.
class CurrentClassCard extends StatelessWidget {
  final String? currentClassName;
  final double classProgress;

  const CurrentClassCard({
    super.key,
    this.currentClassName,
    required this.classProgress,
  });

  @override
  Widget build(BuildContext context) {
    final progressPercentage = (classProgress * 100).toInt();
    final isComplete = classProgress >= 1.0;

    return SacCard(
      child: Column(
        children: [
          // Section header
          Row(
            children: [
              HugeIcon(icon: HugeIcons.strokeRoundedSchool, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Mi Clase',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              if (isComplete)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HugeIcon(
                          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                          size: 14,
                          color: AppColors.secondaryDark),
                      const SizedBox(width: 4),
                      Text(
                        'Completada',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.secondaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Progress ring — size scales with available card width
          LayoutBuilder(
            builder: (context, constraints) {
              final ringSize =
                  (constraints.maxWidth * 0.45).clamp(100.0, 180.0);
              return SacProgressRing(
                progress: classProgress,
                size: ringSize,
                strokeWidth: 10,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$progressPercentage%',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.lightText,
                          ),
                    ),
                    Text(
                      'progreso',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Class name
          Text(
            currentClassName ?? 'Sin clase asignada',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),

          // Motivational text
          Text(
            isComplete
                ? '¡Felicidades! Has completado esta clase.'
                : currentClassName != null
                    ? '¡Sigue adelante, vas muy bien!'
                    : 'Únete a un club para comenzar',
            style: TextStyle(
              fontSize: 14,
              color: isComplete
                  ? AppColors.secondaryDark
                  : AppColors.lightTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
