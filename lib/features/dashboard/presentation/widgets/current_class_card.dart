import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/class_tone.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_progress_ring.dart';
import 'package:sacdia_app/features/classes/presentation/providers/classes_providers.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

import '../utils/open_class_detail.dart';
import 'class_logo_box.dart';

/// Side of the icon well, shared with the «Pendientes» card.
const double _iconWell = 36;

/// Card de clase actual con SacProgressRing - Estilo "Scout Vibrante"
///
/// Fixed compact header row showing the school icon, localized status label,
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
  final bool initialIsExpired;

  const CurrentClassCard({
    super.key,
    this.currentClassName,
    this.currentClassId,
    this.fallbackProgress = 0.0,
    this.initialIsExpired = false,
  });

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the provider once and reuse the result for both progress and logo.
    // value gives us the data immediately once resolved without forcing
    // a loading/error branch split for the logo.
    final classState = currentClassId != null
        ? ref.watch(
            classWithProgressProvider(
              ClassProgressQuery(classId: currentClassId!),
            ),
          )
        : null;

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
    // imageUrl comes from value so it's null while loading (renders asset
    // directly) and fills in if/when the backend provides a URL.
    final String? resolvedName = currentClassName ?? classState?.value?.name;
    final String? imageUrl = classState?.value?.imageUrl;

    final Widget logoWidget = resolvedName != null
        ? AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: KeyedSubtree(
              key: ValueKey(imageUrl),
              child: ClassLogoBox(
                className: resolvedName,
                imageUrl: imageUrl,
                size: _iconWell,
              ),
            ),
          )
        : Container(
            width: _iconWell,
            height: _iconWell,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: SacAccent.of(context).color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusXS + 2),
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedSchool,
              size: 20,
              color: SacAccent.of(context).color,
            ),
          );

    // Same rule as ClassHeroCard: the ring and the percentage speak the class
    // color; the expired/completed badges keep their semantic colors.
    final Color? classColor =
        resolvedName != null ? AppColors.classColor(resolvedName) : null;
    final ClassTone? tone =
        classColor != null ? ClassTone.of(context, classColor) : null;

    final int progressPercentage = (progress * 100).toInt();
    final bool isComplete = progress >= 1.0;
    final bool isExpired =
        initialIsExpired || (classState?.value?.isExpired ?? false);

    // Same frame as the «Pendientes» card: 16 side padding, 14 top and bottom,
    // a 36 icon well and 12 before the text, so both cards share height and
    // text start.
    return SacCard(
      onTap: currentClassId == null
          ? null
          : () => openClassDetail(context, ref, currentClassId!),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Class logo (network → asset → icon fallback)
          logoWidget,
          const SizedBox(width: 12),

          // Label + class name stacked
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr(isExpired
                      ? 'dashboard.class_card.expired_label'
                      : 'dashboard.class_card.label'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.sac.textSecondary,
                        letterSpacing: 0.3,
                      ),
                ),
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
          if (isExpired)
            SacBadge.error(
              label: tr('dashboard.class_card.expired_badge'),
              icon: HugeIcons.strokeRoundedClock04,
            )
          else if (isComplete)
            SacBadge.success(
              label: tr('dashboard.class_card.completed'),
              icon: HugeIcons.strokeRoundedCheckmarkCircle02,
            )
          else
            SacProgressRing(
              progress: progress,
              // 40 keeps the card as tall as «Pendientes».
              size: 40,
              strokeWidth: 4.5,
              animate: false,
              color: classColor,
              trackColor: tone?.container,
              child: Text(
                '$progressPercentage%',
                style: TextStyle(
                  fontSize: SacFontSize.caption,
                  fontWeight: FontWeight.w700,
                  color: tone?.onContainer ?? context.sac.text,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
