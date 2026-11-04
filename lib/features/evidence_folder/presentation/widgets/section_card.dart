import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/animations/sac_state_swap.dart';

import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../domain/entities/evidence_section.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

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
    final dateFormat = DateFormat('d MMM yyyy, HH:mm');
    final showSubmitAction =
        folderIsOpen && section.canSubmit && onSubmit != null;

    return Material(
      key: ValueKey('evidence-section-${section.id}'),
      color: Colors.transparent,
      child: SacInkWell(
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
    final statusLabel = _statusLabel(section.status);
    final color = _statusColor(context.sac, section.status);

    return Semantics(
      label: '${'evidence_folder.section_status_label'.tr()}: $statusLabel',
      child: ExcludeSemantics(
        child: Container(
          key: ValueKey('evidence-section-status-${section.id}'),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.10),
            border: Border.all(color: color, width: 3),
          ),
          alignment: Alignment.center,
          child: HugeIcon(
            icon: _statusIcon(section.status),
            size: 20,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _CompactMetric extends StatelessWidget {
  final HugeIconData icon;
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
    final color = _statusColor(context.sac, status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
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
    final c = context.sac;
    final rows = <Widget>[];

    if (section.submittedByName != null) {
      rows.add(
        _TraceRow(
          icon: HugeIcons.strokeRoundedSent,
          color: c.onInfoContainer,
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
          color: c.onWarningContainer,
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
          color: c.onSuccessContainer,
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
    final info = context.sac.onInfoContainer;
    return Semantics(
      button: true,
      enabled: !isSubmitting,
      label: isSubmitting
          ? 'evidence_folder.sending'.tr()
          : 'evidence_folder.send_to_validation'.tr(),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: Material(
          color: context.sac.infoContainer,
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          child: SacInkWell(
            // Keep the nested action in the gesture arena while loading so a
            // tap never falls through to the parent row navigation.
            onTap: isSubmitting ? () {} : onSubmit,
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SacStateSwap(
                    child: isSubmitting
                        ? SacLoadingSmall(
                            key: const ValueKey('evidence-submit-loading'),
                            color: info,
                          )
                        : HugeIcon(
                            key: const ValueKey('evidence-submit-idle'),
                            icon: HugeIcons.strokeRoundedSent,
                            size: 16,
                            color: info,
                          ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: SacStateSwap(
                      child: Text(
                        isSubmitting
                            ? 'evidence_folder.sending'.tr()
                            : 'evidence_folder.send_to_validation'.tr(),
                        key: ValueKey(
                          isSubmitting
                              ? 'evidence-submit-label-on'
                              : 'evidence-submit-label-off',
                        ),
                        textAlign: TextAlign.center,
                        softWrap: true,
                        style: TextStyle(
                          fontSize: SacFontSize.bodyMedium,
                          fontWeight: FontWeight.w700,
                          color: info,
                          height: 1.2,
                        ),
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
  final HugeIconData icon;
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
            maxLines: 2,
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

Color _statusColor(SacColors c, EvidenceSectionStatus status) {
  switch (status) {
    case EvidenceSectionStatus.pending:
    case EvidenceSectionStatus.preapprovedLf:
      return c.onWarningContainer;
    case EvidenceSectionStatus.submitted:
      return c.onInfoContainer;
    case EvidenceSectionStatus.validated:
      return c.onSuccessContainer;
    case EvidenceSectionStatus.rejected:
      return c.onErrorContainer;
  }
}

HugeIconData _statusIcon(EvidenceSectionStatus status) {
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
