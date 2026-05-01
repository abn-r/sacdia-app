import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
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
    // Watch the provider once and reuse the result for both progress and logo.
    // valueOrNull gives us the data immediately once resolved without forcing
    // a loading/error branch split for the logo.
    final classState =
        currentClassId != null ? ref.watch(classWithProgressProvider(currentClassId!)) : null;

    // ── Progress ─────────────────────────────────────────────────────────────
    // Keeps the existing .when pattern: fallback while loading/error, accurate
    // value once the provider resolves.
    final double progress = classState?.when(
          data: (cwp) => cwp.completionRatio,
          loading: () => fallbackProgress,
          error: (_, __) => fallbackProgress,
        ) ??
        fallbackProgress;

    // ── Logo ─────────────────────────────────────────────────────────────────
    // Resolved on the FIRST frame from the prop — no provider round-trip needed.
    // imageUrl comes from valueOrNull so it's null while loading (renders asset
    // directly) and fills in if/when the backend provides a URL.
    final String? resolvedName =
        currentClassName ?? classState?.valueOrNull?.name;
    final String? imageUrl = classState?.valueOrNull?.imageUrl;

    final Widget logoWidget = resolvedName != null
        ? AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: KeyedSubtree(
              key: ValueKey(imageUrl),
              child: _buildClassLogo(resolvedName, imageUrl),
            ),
          )
        : HugeIcon(
            icon: HugeIcons.strokeRoundedSchool,
            size: 20,
            color: AppColors.primary,
          );

    final int progressPercentage = (progress * 100).toInt();
    final bool isComplete = progress >= 1.0;

    return SacCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Class logo (network → asset → icon fallback)
          logoWidget,
          const SizedBox(width: 10),

          // Label + class name stacked
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr('dashboard.class_card.label'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.sac.textSecondary,
                        letterSpacing: 0.3,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  currentClassName ?? tr('dashboard.class_card.no_class'),
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

  // ─── Logo helper ─────────────────────────────────────────────────────────────

  /// Builds the 40×40 class logo container mirroring the pattern used in
  /// [ClassCard], but scaled down to suit the compact dashboard card.
  Widget _buildClassLogo(String className, String? imageUrl) {
    final classColor = AppColors.classColor(className);
    final logoAsset = AppColors.classLogoAsset(className);

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: classColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: imageUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                memCacheWidth: 120, // 40 * 3 (max device pixel ratio)
                memCacheHeight: 120,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => logoAsset != null
                    ? Padding(
                        padding: const EdgeInsets.all(5),
                        child: Image.asset(
                          logoAsset,
                          fit: BoxFit.contain,
                        ),
                      )
                    : Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedSchool,
                          color: classColor,
                          size: 20,
                        ),
                      ),
              ),
            )
          : logoAsset != null
              ? Padding(
                  padding: const EdgeInsets.all(5),
                  child: Image.asset(
                    logoAsset,
                    fit: BoxFit.contain,
                  ),
                )
              : Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedSchool,
                    color: classColor,
                    size: 20,
                  ),
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
            tr('dashboard.class_card.completed'),
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
