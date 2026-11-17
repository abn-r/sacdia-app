import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/sac_accent.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
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
    final style = EvidenceStatusStyle.of(context, section.status);

    return SacStatusRow(
      key: ValueKey('evidence-section-${section.id}'),
      statusKey: ValueKey('evidence-section-status-${section.id}'),
      style: style,
      title: section.name,
      detail: _detail(context),
      detailIsError: section.status == EvidenceSectionStatus.rejected,
      onTap: onTap,
      trailing: onSubmit == null
          ? null
          : _SendButton(
              sectionId: section.id,
              onPressed: onSubmit!,
              isSubmitting: isSubmitting,
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
