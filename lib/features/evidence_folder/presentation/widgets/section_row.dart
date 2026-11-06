import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../domain/entities/evidence_section.dart';
import 'evidence_folder_summary.dart';
import 'section_status_style.dart';

/// First reviewer note of a section: its evaluation notes, else the first
/// note left on one of its files.
String? evidenceSectionNote(EvidenceSection section) {
  final notes = section.evaluationNotes?.trim();
  if (notes != null && notes.isNotEmpty) return notes;
  for (final file in section.files) {
    final note = file.reviewerNote?.trim();
    if (note != null && note.isNotEmpty) return note;
  }
  return null;
}

/// Eyebrow label and one bordered card with the rows of a group.
class EvidenceSectionGroup extends StatelessWidget {
  const EvidenceSectionGroup({
    super.key,
    required this.label,
    required this.children,
  });

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontSize: SacFontSize.labelSmall,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: c.textTertiary,
                    ),
                  ),
                ),
                Text(
                  '${children.length}',
                  style: TextStyle(
                    fontSize: SacFontSize.labelSmall,
                    fontWeight: FontWeight.w600,
                    color: c.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: c.surface,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              side: BorderSide(color: c.border),
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 58,
                      color: c.divider,
                    ),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One section in a group: status icon, name and the one line that matters
/// in its state. «Enviar» shows only when the section can be sent.
class EvidenceSectionRow extends StatelessWidget {
  const EvidenceSectionRow({
    super.key,
    required this.section,
    required this.onTap,
    this.onSubmit,
    this.isSubmitting = false,
  });

  final EvidenceSection section;
  final VoidCallback onTap;

  /// Null hides «Enviar».
  final VoidCallback? onSubmit;
  final bool isSubmitting;

  String _detail(BuildContext context) {
    final points = formatEvidencePoints(context, section.pointValue);
    switch (section.status) {
      case EvidenceSectionStatus.rejected:
        final note = evidenceSectionNote(section);
        return note != null ? '«$note»' : 'evidence_folder.row.rejected'.tr();
      case EvidenceSectionStatus.pending:
        return section.files.isEmpty
            ? 'evidence_folder.row.no_files'.tr(namedArgs: {'points': points})
            : 'evidence_folder.row.files'.tr(namedArgs: {
                'count': '${section.files.length}',
                'max': '${section.maxFiles}',
                'points': points,
              });
      case EvidenceSectionStatus.submitted:
        final date = section.submittedAt;
        return date == null
            ? 'evidence_folder.state.submitted'.tr()
            : 'evidence_folder.row.submitted_on'.tr(namedArgs: {
                'date': DateFormat(
                  'd MMM',
                  Localizations.localeOf(context).toString(),
                ).format(date.toLocal()),
              });
      case EvidenceSectionStatus.preapprovedLf:
        return 'evidence_folder.row.preapproved'.tr();
      case EvidenceSectionStatus.validated:
        final earned = 'evidence_folder.row.points'.tr(namedArgs: {
          'earned': formatEvidencePoints(context, section.earnedPoints),
          'max': points,
        });
        final hasNote = (section.evaluationNotes?.trim().isNotEmpty ?? false);
        return hasNote && section.earnedPoints < section.pointValue
            ? '$earned · ${'evidence_folder.row.see_note'.tr()}'
            : earned;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final style = EvidenceStatusStyle.of(context, section.status);
    final detail = _detail(context);
    final isRejected = section.status == EvidenceSectionStatus.rejected;

    return SacInkWell(
      key: ValueKey('evidence-section-${section.id}'),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(
            children: [
              Semantics(
                label: style.label,
                child: Container(
                  key: ValueKey('evidence-section-status-${section.id}'),
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: style.container,
                    shape: BoxShape.circle,
                  ),
                  child: ExcludeSemantics(
                    child: HugeIcon(
                      icon: style.icon,
                      size: 17,
                      color: style.onContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      section.name,
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
                      maxLines: isRejected ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        height: 1.35,
                        color:
                            isRejected ? c.onErrorContainer : c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (onSubmit != null)
                _SendButton(
                  sectionId: section.id,
                  onPressed: onSubmit!,
                  isSubmitting: isSubmitting,
                )
              else
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  size: 18,
                  color: c.textTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.sectionId,
    required this.onPressed,
    required this.isSubmitting,
  });

  final String sectionId;
  final VoidCallback onPressed;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    final accent = SacAccent.of(context);
    return TextButton(
      key: ValueKey('evidence-section-submit-$sectionId'),
      onPressed: isSubmitting ? null : onPressed,
      style: TextButton.styleFrom(
        backgroundColor: accent.color,
        foregroundColor: accent.onColor,
        disabledBackgroundColor: accent.light,
        minimumSize: const Size(72, 36),
        tapTargetSize: MaterialTapTargetSize.padded,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontSize: SacFontSize.bodyMedium,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: isSubmitting
          ? const SizedBox(width: 20, height: 20, child: SacLoadingSmall())
          : Text('evidence_folder.row.send'.tr()),
    );
  }
}
