import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:sacdia_app/core/constants/certificate_dates.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/date_formatter.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_date_picker.dart';
import 'package:sacdia_app/core/widgets/sac_pdf_viewer.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor_update.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
import 'package:sacdia_app/features/honors/presentation/utils/honor_level_labels.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_completion_details.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_info_parts.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/instructor_proposal_card.dart';

/// "Información" tab of an enrolled honor: description, the completion date,
/// instructor, study material, work mode and the honor's levels. Shared by the
/// in-app and the external screens.
class HonorWorkInfoTab extends ConsumerWidget {
  const HonorWorkInfoTab({
    super.key,
    required this.userHonor,
    required this.honorId,
    required this.paintColor,
    required this.chipForeground,
    this.honor,
    this.clock,
  });

  final UserHonor userHonor;
  final int honorId;
  final Honor? honor;
  final Color paintColor;

  /// Text color on the level chips (they sit on the paint at 12%).
  final Color chipForeground;

  /// "Today" for the completion date rule; tests inject it.
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final text = Theme.of(context).textTheme;
    final description = honor?.description?.trim();
    final materialUrl = honor?.materialUrl?.trim();
    final editable = userHonor.canSubmit;
    // An approved honor cannot be PATCHed, but a backend that knows proposals
    // lets the member propose another instructor (D11).
    final proposes = userHonor.isCompleted &&
        userHonor.active &&
        userHonor.supportsInstructorProposal;

    // An approved honor without a picked day falls back to when it was
    // validated.
    final dateSet = userHonor.isCompleted
        ? userHonor.completionDate
        : userHonor.completedAt;
    final instructor = userHonor.instructor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (description != null && description.isNotEmpty) ...[
          SacCard(child: HonorClampedDescription(text: description)),
          const SizedBox(height: 12),
        ],
        SacCard(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              HonorInfoRow(
                key: const ValueKey('info-row-date'),
                icon: HugeIcons.strokeRoundedCalendar03,
                well: dateSet == null && editable
                    ? c.warningContainer
                    : paintColor.withValues(alpha: 0.12),
                iconColor: dateSet == null && editable
                    ? c.onWarningContainer
                    : chipForeground,
                title: 'honors.evidence.completion_date_title'.tr(),
                subtitle: dateSet != null
                    ? SacDateFormatter.formatCalendar(dateSet, 'd MMM yyyy')
                    : editable
                        ? 'honors.requirements.info_date_needed'.tr()
                        : null,
                onTap: editable ? () => _pickDate(context, ref) : null,
              ),
              Divider(height: 1, thickness: 1, color: c.borderLight),
              HonorInfoRow(
                key: const ValueKey('info-row-instructor'),
                icon: HugeIcons.strokeRoundedUserAdd01,
                well: paintColor.withValues(alpha: 0.12),
                iconColor: chipForeground,
                title: 'instructor.title'.tr(),
                subtitle: (instructor != null && !instructor.isNone)
                    ? instructor.displayName
                    : editable
                        ? 'honors.requirements.info_instructor_optional'.tr()
                        : 'instructor.none_registered'.tr(),
                onTap: (editable || proposes)
                    ? () => _editInstructor(context)
                    : null,
              ),
              if (materialUrl != null && materialUrl.isNotEmpty) ...[
                Divider(height: 1, thickness: 1, color: c.borderLight),
                HonorInfoRow(
                  key: const ValueKey('info-row-material'),
                  icon: HugeIcons.strokeRoundedPdf01,
                  well: paintColor.withValues(alpha: 0.12),
                  iconColor: chipForeground,
                  title: 'honors.evidence.material_title'.tr(),
                  subtitle: 'honors.evidence.material_subtitle'.tr(),
                  onTap: () => SacPdfViewer.show(
                    context,
                    pdfSource: materialUrl,
                    title: 'honors.evidence.material_title'.tr(),
                  ),
                ),
              ],
              Divider(height: 1, thickness: 1, color: c.borderLight),
              HonorInfoRow(
                key: const ValueKey('info-row-mode'),
                icon: HugeIcons.strokeRoundedRoute01,
                well: paintColor.withValues(alpha: 0.12),
                iconColor: chipForeground,
                title: 'honors.detail.history_mode_label'.tr(),
                subtitle: switch (userHonor.completionMode) {
                  HonorCompletionMode.external =>
                    'honors.detail.mode_external'.tr(),
                  HonorCompletionMode.inApp => 'honors.detail.mode_in_app'.tr(),
                  HonorCompletionMode.undecided =>
                    'honors.detail.mode_undecided'.tr(),
                },
              ),
              Divider(height: 1, thickness: 1, color: c.borderLight),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (honor?.skillLevel != null)
                            HonorLevelChip(
                              label: honorSkillLevelLabel(honor!.skillLevel),
                              background: paintColor.withValues(alpha: 0.12),
                              foreground: chipForeground,
                            ),
                          if (honor != null)
                            HonorLevelChip(
                              label: honorApprovalLabel(honor!.approval),
                              background: paintColor.withValues(alpha: 0.12),
                              foreground: chipForeground,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${'honors.detail.history_registered_label'.tr()} '
                      '${SacDateFormatter.formatCalendar(userHonor.date, 'd MMM yyyy')}',
                      style: text.bodySmall?.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context, WidgetRef ref) =>
      pickHonorCompletionDate(context, ref, userHonor, clock: clock);

  void _editInstructor(BuildContext context) {
    showSacSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLG)),
      ),
      builder: (_) => HonorInstructorSheetBody(userHonor: userHonor),
    );
  }
}

/// Content of the instructor sheet: the optional-instructor card while the
/// honor can still change, or the proposal card on an approved honor of a
/// backend that knows proposals (D11). It follows the saved value so the card
/// redraws after the PATCH.
class HonorInstructorSheetBody extends ConsumerWidget {
  const HonorInstructorSheetBody({super.key, required this.userHonor});

  final UserHonor userHonor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current =
        ref.watch(userHonorForHonorProvider(userHonor.honorId)) ?? userHonor;
    final propose = current.isCompleted &&
        current.active &&
        current.supportsInstructorProposal;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SacSheetHeader(title: 'instructor.title'.tr()),
            if (propose)
              InstructorProposalCard(userHonor: current)
            else
              HonorInstructorCard(userHonor: current),
          ],
        ),
      ),
    );
  }
}

/// Opens the date picker for the honor's completion date and saves it.
/// Shared by the "Información" tab and the submit bar.
Future<void> pickHonorCompletionDate(
  BuildContext context,
  WidgetRef ref,
  UserHonor userHonor, {
  DateTime Function()? clock,
}) async {
  final today = (clock ?? DateTime.now)();
  final first = kMinCertificateDate;
  final last = CertificateDateRule.lastDate(today);
  var initial = userHonor.completedAt ?? last;
  if (initial.isBefore(first)) initial = first;
  if (initial.isAfter(last)) initial = last;
  final picked = await showSacDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first,
    lastDate: last,
    // Localizations, not context.locale: the latter throws when
    // EasyLocalization is not mounted above (tests, previews).
    locale: Localizations.localeOf(context),
  );
  if (picked == null || !context.mounted) return;
  final day = DateTime(picked.year, picked.month, picked.day);
  final notifier = ref.read(honorEvidenceActionsNotifierProvider.notifier);
  final failure = await notifier.saveCompletedAt(
    userId: userHonor.userId,
    honorId: userHonor.honorId,
    completedAt: day,
  );
  if (failure == null || !context.mounted) return;
  final message = switch (failure.errorCode) {
    HonorUpdateErrorCode.dateTooOld => 'honors.evidence.date_too_old'.tr(),
    HonorUpdateErrorCode.dateInFuture => 'honors.evidence.date_future'.tr(),
    HonorUpdateErrorCode.invalidStatus => 'honors.evidence.status_changed'.tr(),
    _ => 'honors.evidence.date_save_error'.tr(),
  };
  if (failure.errorCode == HonorUpdateErrorCode.invalidStatus) {
    notifier.invalidateHonorEvidence(userHonor.honorId);
  }
  SacSnackBar.show(context, message, isError: true);
}
