import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/animations/motion_tokens.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';

/// One module in the certification screen: icon tile, name, «{validated} de
/// {total}» and a thin composition bar. Opens the module screen. Before
/// enrolling ([counts] null) it shows [plainDetail] («3 requisitos») and no
/// bar.
class CertificationModuleRow extends StatelessWidget {
  const CertificationModuleRow({
    super.key,
    required this.moduleId,
    required this.name,
    required this.onTap,
    this.counts,
    this.plainDetail,
  });

  final int moduleId;
  final String name;
  final VoidCallback onTap;
  final StatusCounts? counts;
  final String? plainDetail;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final counts = this.counts;
    final total = counts?.total ?? 0;
    final hasToFix = (counts?.rejected ?? 0) > 0;
    final isDone = counts != null && total > 0 && counts.validated == total;
    final kind = hasToFix
        ? SacStatusKind.rejected
        : isDone
            ? SacStatusKind.validated
            : SacStatusKind.pending;
    final tone = SacStatusStyle.of(context, kind, label: '');

    final String detail;
    if (counts == null) {
      detail = plainDetail ?? '';
    } else {
      final progress = 'certifications.view.module_progress'.tr(
        namedArgs: {'done': '${counts.validated}', 'total': '$total'},
      );
      final notStarted =
          counts.validated + counts.review + counts.rejected == 0;
      detail = [
        if (hasToFix)
          'certifications.status.legend_rejected'.plural(counts.rejected),
        progress,
        if (!hasToFix && notStarted)
          'certifications.view.module_not_started'.tr(),
      ].join(' · ');
    }

    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      onTap: onTap,
      label: 'certifications.view.module_semantics'
          .tr(namedArgs: {'name': name, 'progress': detail}),
      child: SacInkWell(
        onTap: onTap,
        pressedScale: SacMotion.rowPressScale,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tone.container,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXS),
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedFolder01,
                    size: 17,
                    color: tone.onContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: SacFontSize.titleMedium,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                          color: c.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: SacFontSize.bodySmall,
                          height: 1.35,
                          color:
                              hasToFix ? c.onErrorContainer : c.textSecondary,
                        ),
                      ),
                      if (counts != null) ...[
                        const SizedBox(height: 8),
                        _ModuleBar(
                          key: ValueKey('certification-module-bar-$moduleId'),
                          counts: counts,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  size: 18,
                  color: c.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Thin bar split by how many requirements are validated, sent and to fix;
/// the rest of the track is «not sent».
class _ModuleBar extends StatelessWidget {
  const _ModuleBar({super.key, required this.counts});

  final StatusCounts counts;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    Color solid(SacStatusKind k) =>
        SacStatusStyle.of(context, k, label: '').solid;
    final all = [
      (counts.validated, solid(SacStatusKind.validated)),
      (counts.review, solid(SacStatusKind.review)),
      (counts.rejected, solid(SacStatusKind.rejected)),
      if (counts.total > 0) (counts.pending, c.divider),
    ];
    final hasParts = all.any((p) => p.$1 > 0);

    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        child: SizedBox(
          height: 4,
          child: hasParts
              ? SacSegmentRow(
                  gap: 0,
                  parts: [for (final p in all) SacSegmentPart(p.$1, p.$2)],
                )
              : ColoredBox(color: c.divider),
        ),
      ),
    );
  }
}
