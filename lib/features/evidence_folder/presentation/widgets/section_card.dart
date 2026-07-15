import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/evidence_section.dart';

/// Compact row that summarizes an [EvidenceSection] inside the grouped list.
class SectionCard extends StatelessWidget {
  final EvidenceSection section;
  final VoidCallback onTap;

  /// Whether the folder accepts mutations. Controls the submit action.
  final bool folderIsOpen;

  /// Callback for submitting the section for validation.
  final VoidCallback? onSubmit;

  /// Whether this section is currently being submitted.
  final bool isSubmitting;

  const SectionCard({
    super.key,
    required this.section,
    required this.onTap,
    this.folderIsOpen = true,
    this.onSubmit,
    this.isSubmitting = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final dateFormat = DateFormat('d MMM yyyy, HH:mm', 'es');
    final showSubmitAction =
        folderIsOpen && section.canSubmit && onSubmit != null;

    return Material(
      key: ValueKey('evidence-section-${section.id}'),
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _SectionProgressIndicator(section: section),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: c.text,
                                    height: 1.2,
                                  ),
                        ),
                        if (section.description case final description?
                            when description.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: c.textSecondary,
                                      height: 1.35,
                                    ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _CompactStatusLabel(status: section.status),
                            _CompactMetric(
                              icon: HugeIcons.strokeRoundedStar,
                              label:
                                  'evidence_folder.points_ratio'.tr(namedArgs: {
                                'earned': '${section.earnedPoints}',
                                'max': '${section.pointValue}',
                              }),
                            ),
                            _CompactMetric(
                              icon: HugeIcons.strokeRoundedFiles01,
                              label:
                                  'evidence_folder.files_ratio'.tr(namedArgs: {
                                'current': '${section.files.length}',
                                'max': '${section.maxFiles}',
                              }),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    size: 19,
                    color: c.textTertiary,
                  ),
                ],
              ),
              if (_hasTraceability(section)) ...[
                const SizedBox(height: 10),
                _TraceabilitySummary(
                  section: section,
                  dateFormat: dateFormat,
                ),
              ],
              if (showSubmitAction) ...[
                const SizedBox(height: 10),
                _SubmitSectionButton(
                  key: ValueKey('evidence-section-submit-${section.id}'),
                  isSubmitting: isSubmitting,
                  onSubmit: onSubmit!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionProgressIndicator extends StatelessWidget {
  final EvidenceSection section;

  const _SectionProgressIndicator({required this.section});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final filesProgress = section.maxFiles <= 0
        ? 0.0
        : (section.files.length / section.maxFiles).clamp(0.0, 1.0);
    final statusLabel = _statusLabel(section.status);
    final filesLabel = 'evidence_folder.files_ratio'.tr(namedArgs: {
      'current': '${section.files.length}',
      'max': '${section.maxFiles}',
    });
    final color = _statusColor(section.status);

    return Semantics(
      label:
          '${'evidence_folder.section_status_label'.tr()}: $statusLabel. $filesLabel',
      child: ExcludeSemantics(
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  value: filesProgress,
                  strokeWidth: 3,
                  backgroundColor: c.divider,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              HugeIcon(
                icon: _statusIcon(section.status),
                size: 17,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactMetric extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String label;

  const _CompactMetric({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: HugeIcon(icon: icon, size: 13, color: c.textSecondary),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            softWrap: true,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: c.textSecondary,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
          ),
        ),
      ],
    );
  }
}

class _CompactStatusLabel extends StatelessWidget {
  final EvidenceSectionStatus status;

  const _CompactStatusLabel({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        _statusLabel(status),
        softWrap: true,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
      ),
    );
  }
}

class _TraceabilitySummary extends StatelessWidget {
  final EvidenceSection section;
  final DateFormat dateFormat;

  const _TraceabilitySummary({
    required this.section,
    required this.dateFormat,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    if (section.submittedByName != null) {
      rows.add(
        _TraceRow(
          icon: HugeIcons.strokeRoundedSent,
          color: AppColors.info,
          text: 'evidence_folder.trace.sent_by'.tr(namedArgs: {
            'name': section.submittedByName!,
            'date': _formattedDate(section.submittedAt),
          }),
        ),
      );
    }
    if (section.lfApproverName != null) {
      rows.add(
        _TraceRow(
          icon: HugeIcons.strokeRoundedAnalytics01,
          color: AppColors.accentDark,
          text: 'evidence_folder.trace.preapproved_by'.tr(namedArgs: {
            'name': section.lfApproverName!,
            'date': _formattedDate(section.lfApprovedAt),
          }),
        ),
      );
    }
    if (section.unionApproverName != null) {
      rows.add(
        _TraceRow(
          icon: HugeIcons.strokeRoundedCheckmarkCircle01,
          color: AppColors.secondaryDark,
          text: 'evidence_folder.trace.validated_by'.tr(namedArgs: {
            'name': section.unionApproverName!,
            'date': _formattedDate(section.unionApprovedAt),
          }),
        ),
      );
    }
    if (section.evaluationNotes case final notes? when notes.isNotEmpty) {
      rows.add(
        _TraceRow(
          icon: HugeIcons.strokeRoundedNote,
          color: context.sac.textSecondary,
          text: notes,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < rows.length; index++) ...[
          if (index > 0) const SizedBox(height: 4),
          rows[index],
        ],
      ],
    );
  }

  String _formattedDate(DateTime? date) =>
      date == null ? '' : ' · ${dateFormat.format(date.toLocal())}';
}

class _SubmitSectionButton extends StatelessWidget {
  final bool isSubmitting;
  final VoidCallback onSubmit;

  const _SubmitSectionButton({
    super.key,
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !isSubmitting,
      label: isSubmitting
          ? 'evidence_folder.sending'.tr()
          : 'evidence_folder.send_to_validation'.tr(),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: Material(
          color: AppColors.info.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            // Keep the nested action in the gesture arena while loading so a
            // tap never falls through to the parent row navigation.
            onTap: isSubmitting ? () {} : onSubmit,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (isSubmitting)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.info),
                      ),
                    )
                  else
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedSent,
                      size: 16,
                      color: AppColors.info,
                    ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      isSubmitting
                          ? 'evidence_folder.sending'.tr()
                          : 'evidence_folder.send_to_validation'.tr(),
                      textAlign: TextAlign.center,
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.info,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TraceRow extends StatelessWidget {
  final List<List<dynamic>> icon;
  final Color color;
  final String text;

  const _TraceRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        HugeIcon(icon: icon, size: 12, color: color),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  height: 1.3,
                ),
          ),
        ),
      ],
    );
  }
}

bool _hasTraceability(EvidenceSection section) =>
    section.submittedByName != null ||
    section.lfApproverName != null ||
    section.unionApproverName != null ||
    (section.evaluationNotes?.isNotEmpty ?? false);

String _statusLabel(EvidenceSectionStatus status) {
  switch (status) {
    case EvidenceSectionStatus.pending:
      return 'evidence_folder.status.pending'.tr();
    case EvidenceSectionStatus.submitted:
      return 'evidence_folder.status.submitted'.tr();
    case EvidenceSectionStatus.preapprovedLf:
      return 'evidence_folder.status.preapproved'.tr();
    case EvidenceSectionStatus.validated:
      return 'evidence_folder.status.validated'.tr();
    case EvidenceSectionStatus.rejected:
      return 'evidence_folder.status.rejected'.tr();
  }
}

Color _statusColor(EvidenceSectionStatus status) {
  switch (status) {
    case EvidenceSectionStatus.pending:
      return AppColors.accentDark;
    case EvidenceSectionStatus.submitted:
      return AppColors.info;
    case EvidenceSectionStatus.preapprovedLf:
      return AppColors.accent;
    case EvidenceSectionStatus.validated:
      return AppColors.secondary;
    case EvidenceSectionStatus.rejected:
      return AppColors.error;
  }
}

List<List<dynamic>> _statusIcon(EvidenceSectionStatus status) {
  switch (status) {
    case EvidenceSectionStatus.pending:
      return HugeIcons.strokeRoundedClock01;
    case EvidenceSectionStatus.submitted:
      return HugeIcons.strokeRoundedSent;
    case EvidenceSectionStatus.preapprovedLf:
      return HugeIcons.strokeRoundedAnalytics01;
    case EvidenceSectionStatus.validated:
      return HugeIcons.strokeRoundedCheckmarkCircle01;
    case EvidenceSectionStatus.rejected:
      return HugeIcons.strokeRoundedCancel01;
  }
}
