import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/evidence_folder.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

/// Banner prominente que se muestra cuando la Carpeta Anual de Evidencias no está abierta.
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
    final dateFormat = DateFormat('d MMM yyyy');
    final dateStr = folder.evaluatedAt != null
        ? ' · ${dateFormat.format(folder.evaluatedAt!.toLocal())}'
        : '';

    final c = context.sac;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.successContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: c.success.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusXS),
            ),
            child: Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedStar,
                size: 22,
                color: c.onSuccessContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'evidence_folder.evaluated_banner.title'
                      .tr(namedArgs: {'date': dateStr}),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: c.onSuccessContainer,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'evidence_folder.evaluated_banner.points'.tr(namedArgs: {
                    'earned': '${folder.earnedPoints}',
                    'max': '${folder.maxPoints}',
                  }),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: c.onSuccessContainer,
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
    final c = context.sac;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.warningContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: c.warning.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.warning.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusXS),
            ),
            child: Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedLocked,
                size: 22,
                color: c.onWarningContainer,
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
                        color: c.onWarningContainer,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'evidence_folder.closed_banner.description'.tr(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: c.onWarningContainer,
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
