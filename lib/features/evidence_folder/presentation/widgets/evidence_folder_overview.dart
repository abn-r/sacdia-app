import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/evidence_folder.dart';
import '../../domain/entities/evidence_section.dart';

/// Hero principal de la carpeta con progreso y estado operativo.
class EvidenceFolderHero extends StatelessWidget {
  final EvidenceFolder folder;

  const EvidenceFolderHero({
    super.key,
    required this.folder,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final progress = folder.completionRatio.clamp(0.0, 1.0).toDouble();
    final percentage = (progress * 100).round();
    final status = _folderStatus(folder);
    final pointsLabel = 'evidence_folder.points_ratio'.tr(namedArgs: {
      'earned': '${folder.earnedPoints}',
      'max': '${folder.maxPoints}',
    });

    return Semantics(
      key: const ValueKey('evidence-folder-hero'),
      container: true,
      label: 'AVANCE: $percentage%, $pointsLabel, ${status.label}',
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: status.color.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    folder.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: c.textTertiary,
                      letterSpacing: 0.88,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'AVANCE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: c.textTertiary,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$percentage%',
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      color: AppColors.coral500,
                      height: 1,
                      letterSpacing: -1.3,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const HugeIcon(
                        icon: HugeIcons.strokeRoundedStar,
                        size: 15,
                        color: AppColors.accentDark,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          pointsLabel,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _FolderStatusBadge(status: status),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 6,
                      strokeCap: StrokeCap.round,
                      backgroundColor: c.borderLight,
                      color: AppColors.coral500,
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.coral50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const HugeIcon(
                      icon: HugeIcons.strokeRoundedFolder01,
                      size: 23,
                      color: AppColors.coral600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FolderStatusBadge extends StatelessWidget {
  final _FolderStatus status;

  const _FolderStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: status.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: status.icon, size: 13, color: status.color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              status.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: status.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Conteos independientes de secciones por cada estado del backend.
class EvidenceStatusPills extends StatelessWidget {
  final List<EvidenceSection> sections;

  const EvidenceStatusPills({
    super.key,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    final statuses = [
      _SectionStatusPillData(
        keyName: 'evidence-status-validated',
        status: EvidenceSectionStatus.validated,
        label: 'evidence_folder.status.validated'.tr(),
        icon: HugeIcons.strokeRoundedCheckmarkCircle02,
        color: context.sac.success,
      ),
      _SectionStatusPillData(
        keyName: 'evidence-status-preapproved',
        status: EvidenceSectionStatus.preapprovedLf,
        label: 'evidence_folder.status.preapproved'.tr(),
        icon: HugeIcons.strokeRoundedAnalytics01,
        color: context.sac.warning,
      ),
      _SectionStatusPillData(
        keyName: 'evidence-status-submitted',
        status: EvidenceSectionStatus.submitted,
        label: 'evidence_folder.status.submitted'.tr(),
        icon: HugeIcons.strokeRoundedSent,
        color: context.sac.info,
      ),
      _SectionStatusPillData(
        keyName: 'evidence-status-rejected',
        status: EvidenceSectionStatus.rejected,
        label: 'evidence_folder.status.rejected'.tr(),
        icon: HugeIcons.strokeRoundedCancelCircle,
        color: context.sac.error,
      ),
      _SectionStatusPillData(
        keyName: 'evidence-status-pending',
        status: EvidenceSectionStatus.pending,
        label: 'evidence_folder.status.pending'.tr(),
        icon: HugeIcons.strokeRoundedClock01,
        color: context.sac.textSecondary,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          for (var index = 0; index < statuses.length; index++) ...[
            _EvidenceStatusPill(
              data: statuses[index],
              count: sections
                  .where((section) => section.status == statuses[index].status)
                  .length,
            ),
            if (index != statuses.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _EvidenceStatusPill extends StatelessWidget {
  final _SectionStatusPillData data;
  final int count;

  const _EvidenceStatusPill({
    required this.data,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${data.label}: $count',
      child: Container(
        key: ValueKey(data.keyName),
        constraints: const BoxConstraints(minHeight: 42),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: data.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: data.color.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(icon: data.icon, size: 15, color: data.color),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: data.color,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              data.label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: context.sac.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Campo de búsqueda controlado para filtrar las secciones visibles.
class EvidenceSectionSearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const EvidenceSectionSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: AnimatedBuilder(
        animation: focusNode,
        builder: (context, child) {
          final isFocused = focusNode.hasFocus;
          return TextField(
            key: const ValueKey('evidence-section-search'),
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'evidence_folder.search_hint'.tr(),
              prefixIcon: HugeIcon(
                icon: HugeIcons.strokeRoundedSearch01,
                size: 20,
                color: isFocused ? AppColors.coral600 : c.textTertiary,
              ),
              suffixIcon: query.isEmpty
                  ? null
                  : Semantics(
                      button: true,
                      label: 'common.clear'.tr(),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: IconButton(
                          tooltip: 'common.clear'.tr(),
                          onPressed: onClear,
                          icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedCancel01,
                            size: 19,
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                    ),
              filled: true,
              fillColor: c.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: c.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppColors.coral500, width: 1.5),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Estado vacío cuando una consulta no coincide con ninguna sección.
class EvidenceSearchEmpty extends StatelessWidget {
  const EvidenceSearchEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Padding(
      key: const ValueKey('evidence-search-empty'),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 44),
      child: Column(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedSearchRemove,
            size: 48,
            color: c.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            'common.no_results'.tr(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'evidence_folder.search_empty_hint'.tr(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: c.textSecondary,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }
}

class _FolderStatus {
  final String label;
  final List<List<dynamic>> icon;
  final Color color;

  const _FolderStatus({
    required this.label,
    required this.icon,
    required this.color,
  });
}

_FolderStatus _folderStatus(EvidenceFolder folder) {
  if (folder.isEvaluated) {
    return _FolderStatus(
      label: 'evidence_folder.status.validated'.tr(),
      icon: HugeIcons.strokeRoundedCheckmarkCircle02,
      color: AppColors.secondaryDark,
    );
  }
  if (folder.isUnderEvaluation) {
    return _FolderStatus(
      label: 'evidence_folder.evaluation_banner.title'.tr(),
      icon: HugeIcons.strokeRoundedAnalytics01,
      color: AppColors.accentDark,
    );
  }
  if (folder.status == 'submitted') {
    return _FolderStatus(
      label: 'evidence_folder.status.submitted'.tr(),
      icon: HugeIcons.strokeRoundedSent,
      color: AppColors.info,
    );
  }
  if (folder.status == 'closed' || !folder.isOpen) {
    return _FolderStatus(
      label: 'evidence_folder.status.closed'.tr(),
      icon: HugeIcons.strokeRoundedLocked,
      color: AppColors.errorDark,
    );
  }
  return _FolderStatus(
    label: 'evidence_folder.status.open'.tr(),
    icon: HugeIcons.strokeRoundedLock,
    color: AppColors.secondaryDark,
  );
}

class _SectionStatusPillData {
  final String keyName;
  final EvidenceSectionStatus status;
  final String label;
  final List<List<dynamic>> icon;
  final Color color;

  const _SectionStatusPillData({
    required this.keyName,
    required this.status,
    required this.label,
    required this.icon,
    required this.color,
  });
}
