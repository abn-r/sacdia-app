import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_progress_ring.dart';
import 'package:sacdia_app/features/classes/presentation/providers/classes_providers.dart';

/// Card de clase actual con SacProgressRing - Estilo "Scout Vibrante"
///
/// Fixed compact header row showing the school icon, "Mi Clase" label,
/// the class name below, a small progress ring with the percentage, and
/// the "Completada" badge when progress reaches 100%.
///
/// Progress is sourced from [classWithProgressProvider] (the same provider
/// used by "Mis Clases") to ensure the percentage is always consistent with
/// the detail screen. The dashboard summary's [classProgress] field is used
/// only as a fallback while the accurate data is loading or when no class
/// ID is available.
class CurrentClassCard extends ConsumerWidget {
  final String? currentClassName;

  /// ID de la clase actual — requerido para obtener el progreso preciso desde
  /// [classWithProgressProvider]. Si es null, se muestra [fallbackProgress].
  final int? currentClassId;

  /// Progreso de respaldo proveniente del dashboard summary (0.0–1.0).
  /// Se muestra mientras [classWithProgressProvider] carga o cuando
  /// [currentClassId] es null.
  final double fallbackProgress;

  const CurrentClassCard({
    super.key,
    this.currentClassName,
    this.currentClassId,
    this.fallbackProgress = 0.0,
  });

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Resolve the accurate progress from the classes provider when we have an
    // ID. Falls back to [fallbackProgress] on loading, error, or missing ID.
    final double progress;
    if (currentClassId != null) {
      final classState = ref.watch(classWithProgressProvider(currentClassId!));
      progress = classState.when(
        data: (classWithProgress) => classWithProgress.completionRatio,
        loading: () => fallbackProgress,
        error: (_, __) => fallbackProgress,
      );
    } else {
      progress = fallbackProgress;
    }

    final int progressPercentage = (progress * 100).toInt();
    final bool isComplete = progress >= 1.0;

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
          if (isComplete)
            const _CompletadaBadge()
          else
            SacProgressRing(
              progress: progress,
              size: 44,
              strokeWidth: 5,
              animate: false,
              child: Text(
                '$progressPercentage%',
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
