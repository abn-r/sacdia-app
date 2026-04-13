import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_progress_ring.dart';

/// Card de clase actual con SacProgressRing - Estilo "Scout Vibrante"
///
/// Fixed compact header row showing the school icon, "Mi Clase" label,
/// the class name below, a small progress ring with the percentage, and
/// the "Completada" badge when progress reaches 100%.
class CurrentClassCard extends StatelessWidget {
  final String? currentClassName;
  final double classProgress;

  const CurrentClassCard({
    super.key,
    this.currentClassName,
    required this.classProgress,
  });

  // ─── Helpers ─────────────────────────────────────────────────────────────

  int get _progressPercentage => (classProgress * 100).toInt();
  bool get _isComplete => classProgress >= 1.0;

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SacCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // School icon
          HugeIcon(
            icon: HugeIcons.strokeRoundedSchool,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),

          // Label + class name stacked
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Mi Clase',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.sac.textSecondary,
                        letterSpacing: 0.3,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  currentClassName ?? 'Sin clase asignada',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.sac.text,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Small progress ring + percentage, OR "Completada" badge
          if (_isComplete)
            const _CompletadaBadge()
          else
            SacProgressRing(
              progress: classProgress,
              size: 44,
              strokeWidth: 5,
              animate: false,
              child: Text(
                '$_progressPercentage%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: context.sac.text,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Private badge widget ─────────────────────────────────────────────────────

class _CompletadaBadge extends StatelessWidget {
  const _CompletadaBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
            color: AppColors.secondaryDark,
          ),
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
    );
  }
}
