import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:sacdia_app/core/constants/certificate_dates.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/date_formatter.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
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

/// "Información" tab: description, the completion date, instructor, study
/// material, work mode and the honor's levels.
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

    final dateSet = userHonor.completedAt;
    final instructor = userHonor.instructor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (description != null && description.isNotEmpty) ...[
          SacCard(child: _ClampedDescription(text: description)),
          const SizedBox(height: 12),
        ],
        SacCard(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              _InfoRow(
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
              _InfoRow(
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
                onTap: editable ? () => _editInstructor(context) : null,
              ),
              if (materialUrl != null && materialUrl.isNotEmpty) ...[
                Divider(height: 1, thickness: 1, color: c.borderLight),
                _InfoRow(
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
              _InfoRow(
                key: const ValueKey('info-row-mode'),
                icon: HugeIcons.strokeRoundedRoute01,
                well: paintColor.withValues(alpha: 0.12),
                iconColor: chipForeground,
                title: 'honors.detail.history_mode_label'.tr(),
                subtitle: 'honors.detail.mode_in_app'.tr(),
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
                            _LevelChip(
                              label: honorSkillLevelLabel(honor!.skillLevel),
                              background: paintColor.withValues(alpha: 0.12),
                              foreground: chipForeground,
                            ),
                          if (honor != null)
                            _LevelChip(
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

  Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
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
      locale: context.locale,
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
      HonorUpdateErrorCode.invalidStatus =>
        'honors.evidence.status_changed'.tr(),
      _ => 'honors.evidence.date_save_error'.tr(),
    };
    if (failure.errorCode == HonorUpdateErrorCode.invalidStatus) {
      notifier.invalidateHonorEvidence(userHonor.honorId);
    }
    SacSnackBar.show(context, message, isError: true);
  }

  void _editInstructor(BuildContext context) {
    showSacSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLG)),
      ),
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          // Follows the saved value so the card redraws after the PATCH.
          final current =
              ref.watch(userHonorForHonorProvider(honorId)) ?? userHonor;
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
                  HonorInstructorCard(userHonor: current),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    super.key,
    required this.icon,
    required this.well,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final HugeIconData icon;
  final Color well;
  final Color iconColor;
  final String title;
  final String? subtitle;

  /// Null makes the row read-only (no chevron, no tap).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final text = Theme.of(context).textTheme;

    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: well,
                borderRadius: BorderRadius.circular(AppTheme.radiusXS),
              ),
              child: Center(
                child: HugeIcon(icon: icon, size: 20, color: iconColor),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: c.textSecondary),
                    ),
                ],
              ),
            ),
            if (onTap != null)
              ExcludeSemantics(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  size: 18,
                  color: c.textTertiary,
                ),
              ),
          ],
        ),
      ),
    );

    return MergeSemantics(
      child: Semantics(
        button: onTap != null,
        child: onTap == null
            ? content
            : InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
                child: content,
              ),
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: foreground,
              height: 1,
            ),
      ),
    );
  }
}

class _ClampedDescription extends StatefulWidget {
  const _ClampedDescription({required this.text});

  final String text;

  @override
  State<_ClampedDescription> createState() => _ClampedDescriptionState();
}

class _ClampedDescriptionState extends State<_ClampedDescription> {
  static const _maxLines = 4;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: c.textSecondary,
          height: 1.5,
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: _maxLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              maxLines: _expanded ? null : _maxLines,
              overflow: _expanded ? TextOverflow.visible : TextOverflow.fade,
              style: style,
            ),
            if (overflows)
              Semantics(
                button: true,
                child: InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _expanded
                            ? 'honors.requirements.see_less'.tr()
                            : 'honors.requirements.see_more'.tr(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: c.textSecondary,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
