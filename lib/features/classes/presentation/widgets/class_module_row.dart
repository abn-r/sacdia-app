import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/class_module_detail.dart';
import '../utils/member_requirement_groups.dart';

/// One module in the class screen: icon tile, name, "{validated} de {total}"
/// and a thin composition bar. Opens the module screen.
class ClassModuleRow extends StatelessWidget {
  const ClassModuleRow({super.key, required this.module, required this.onTap});

  final ClassModuleDetail module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final counts = countRequirements(module.requirements);
    final total = counts.total;
    final hasToFix = counts.rejected > 0;
    final isDone = total > 0 && counts.validated == total;

    final kind = hasToFix
        ? SacStatusKind.rejected
        : isDone
            ? SacStatusKind.validated
            : SacStatusKind.pending;
    final tone = SacStatusStyle.of(context, kind, label: '');

    final progress = 'classes.detail_with_progress.module_progress'.tr(
      namedArgs: {'done': '${counts.validated}', 'total': '$total'},
    );
    final notStarted =
        counts.validated + counts.submitted + counts.rejected == 0;
    final toFix = hasToFix
        ? 'classes.grouped.legend_rejected'.plural(counts.rejected)
        : null;
    final detail = [
      if (toFix != null) toFix,
      progress,
      if (!hasToFix && notStarted)
        'classes.detail_with_progress.module_not_started'.tr(),
    ].join(' · ');

    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      onTap: onTap,
      label: 'classes.detail_with_progress.module_semantics'
          .tr(namedArgs: {'name': module.name, 'progress': detail}),
      child: SacInkWell(
        onTap: onTap,
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
                        module.name,
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
                      const SizedBox(height: 8),
                      _ModuleBar(
                        key: ValueKey('module-bar-${module.id}'),
                        validated: counts.validated,
                        sent: counts.submitted,
                        toFix: counts.rejected,
                        total: total,
                      ),
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
/// the rest of the track is "not sent".
class _ModuleBar extends StatelessWidget {
  const _ModuleBar({
    super.key,
    required this.validated,
    required this.sent,
    required this.toFix,
    required this.total,
  });

  final int validated;
  final int sent;
  final int toFix;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    Color solid(SacStatusKind k) =>
        SacStatusStyle.of(context, k, label: '').solid;
    final rest = total - validated - sent - toFix;
    final all = [
      (validated, solid(SacStatusKind.validated)),
      (sent, solid(SacStatusKind.review)),
      (toFix, solid(SacStatusKind.rejected)),
      if (total > 0) (rest, c.divider),
    ];
    final parts = all.where((p) => p.$1 > 0).toList();

    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        child: SizedBox(
          height: 4,
          child: parts.isEmpty
              ? ColoredBox(color: c.divider)
              : SacSegmentRow(
                  gap: 0,
                  parts: [for (final p in all) SacSegmentPart(p.$1, p.$2)],
                ),
        ),
      ),
    );
  }
}
