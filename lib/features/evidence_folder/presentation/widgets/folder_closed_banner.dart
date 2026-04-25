import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/evidence_folder.dart';

/// Banner prominente que se muestra cuando la carpeta de evidencias no está abierta.
///
/// Muestra dos variantes:
/// - **evaluated** → carpeta evaluada con puntos totales y fecha.
/// - **closed/otros** → carpeta cerrada, sugiere contactar administración.
class FolderClosedBanner extends StatelessWidget {
  final EvidenceFolder folder;

  const FolderClosedBanner({super.key, required this.folder});

  @override
  Widget build(BuildContext context) {
    if (folder.isEvaluated) {
      return _EvaluatedBanner(folder: folder);
    }
    return const _ClosedBanner();
  }
}

// ── Variante: Carpeta evaluada con puntos ─────────────────────────────────────

class _EvaluatedBanner extends StatelessWidget {
  final EvidenceFolder folder;

  const _EvaluatedBanner({required this.folder});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM yyyy', 'es');
    final dateStr = folder.evaluatedAt != null
        ? ' · ${dateFormat.format(folder.evaluatedAt!.toLocal())}'
        : '';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondaryLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedStar,
                size: 22,
                color: AppColors.secondaryDark,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'evidence_folder.evaluated_banner.title'.tr(namedArgs: {'date': dateStr}),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondaryDark,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'evidence_folder.evaluated_banner.points'.tr(namedArgs: {
                    'earned': '${folder.earnedPoints}',
                    'max': '${folder.maxPoints}',
                  }),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.secondaryDark,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
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

// ── Variante: Carpeta cerrada (sin evaluación) ────────────────────────────────

class _ClosedBanner extends StatelessWidget {
  const _ClosedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedLocked,
                size: 22,
                color: AppColors.accentDark,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'evidence_folder.closed_banner.title'.tr(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentDark,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'evidence_folder.closed_banner.description'.tr(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.accentDark,
                        height: 1.45,
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
