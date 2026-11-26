import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/money_format.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_tone.dart';
import 'package:sacdia_app/core/widgets/sac_value_row.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_grouped_section.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_enrollment.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_enrollments_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_actions.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_decision_sheet.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_format.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_messages.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_quote.dart';

/// Server limits of a rejection reason.
const int _kReasonMinLength = 5;
const int _kReasonMaxLength = 500;

/// «Conquistadores · Asociación Norte», skipping whatever the server omitted.
String enrollmentPlaceLine(SupervisionEnrollment enrollment) => [
      enrollment.clubTypeName,
      enrollment.localFieldName,
    ].where((part) => part.trim().isNotEmpty).join(' · ');

/// Opens one enrollment: what the club declared and, for an actor with
/// `club_enrollments.validate` on a pending one, the decision.
Future<void> showSupervisionEnrollmentSheet(
  BuildContext context,
  SupervisionEnrollment enrollment,
) {
  return showSacSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _EnrollmentSheet(enrollment: enrollment),
  );
}

class _EnrollmentSheet extends ConsumerStatefulWidget {
  const _EnrollmentSheet({required this.enrollment});

  final SupervisionEnrollment enrollment;

  @override
  ConsumerState<_EnrollmentSheet> createState() => _EnrollmentSheetState();
}

class _EnrollmentSheetState extends ConsumerState<_EnrollmentSheet> {
  bool _busy = false;
  String? _error;

  SupervisionEnrollment get _enrollment => widget.enrollment;

  /// Approving needs no second dialog: the sheet already shows everything
  /// that is being approved.
  Future<void> _approve() => _decide(
        () => ref
            .read(supervisionEnrollmentsProvider.notifier)
            .approve(_enrollment.id),
        'supervision.enrollments.approved_toast',
      );

  Future<void> _reject() async {
    final reason = await showSupervisionDecisionSheet(
      context: context,
      title: 'supervision.enrollments.reject_heading'
          .tr(args: [_enrollment.clubName]),
      message: 'supervision.enrollments.reject_message'.tr(),
      fieldLabel: 'supervision.enrollments.reason_label'.tr(),
      fieldHint: 'supervision.enrollments.reason_hint'.tr(),
      confirmLabel: 'supervision.enrollments.reject_title'.tr(),
      minLength: _kReasonMinLength,
      maxLength: _kReasonMaxLength,
    );
    if (reason == null || !mounted) return;
    await _decide(
      () => ref
          .read(supervisionEnrollmentsProvider.notifier)
          .reject(_enrollment.id, reason),
      'supervision.enrollments.rejected_toast',
    );
  }

  Future<void> _decide(
    Future<String?> Function() action,
    String successKey,
  ) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final failure = await action();
    if (!mounted) return;
    if (failure == null) {
      SacSnackBar.show(context, successKey.tr(), isSuccess: true);
      Navigator.of(context).pop();
      return;
    }
    final code = ref.read(supervisionEnrollmentsProvider).lastActionErrorCode;
    // Someone else already decided it: nothing left to do in this sheet.
    if (code == 'CE_ENROLLMENT_NOT_PENDING' ||
        code == 'CE_ENROLLMENT_NOT_FOUND') {
      SacSnackBar.show(
        context,
        'supervision.enrollments.error_not_pending'.tr(),
        isError: true,
      );
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _error = code == 'CE_SELF_REVIEW'
          ? 'supervision.enrollments.error_self_review'.tr()
          : supervisionErrorMessage(failure);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider.select((v) => v.value));
    final canDecide = hasCapability(user, 'club_enrollments.validate') &&
        _enrollment.status == SupervisionEnrollmentStatus.pendingValidation;
    final subtitle = [
      enrollmentPlaceLine(_enrollment),
      _enrollment.yearName,
    ].where((part) => part.trim().isNotEmpty).join(' · ');

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SacSheetHeader(title: _enrollment.clubName, subtitle: subtitle),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16),
              child: _EnrollmentFacts(enrollment: _enrollment),
            ),
          ),
          if (_error != null) SupervisionInlineError(message: _error!),
          if (canDecide)
            SupervisionSheetFooter(
              child: SupervisionStackedActions(
                primaryLabel: 'supervision.enrollments.approve_action'.tr(),
                primaryIcon: HugeIcons.strokeRoundedTick02,
                onPrimary: _approve,
                secondaryLabel: 'coordinator.actions.reject'.tr(),
                secondaryIcon: HugeIcons.strokeRoundedCancel01,
                onSecondary: _reject,
                isLoading: _busy,
              ),
            )
          else
            const SafeArea(top: false, child: SizedBox(height: 4)),
        ],
      ),
    );
  }
}

/// Everything the club declared, in two groups, the rejection reason quoted
/// and the request info as a small note. A row exists only when the server
/// sent its value.
class _EnrollmentFacts extends StatelessWidget {
  const _EnrollmentFacts({required this.enrollment});

  final SupervisionEnrollment enrollment;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    String date(DateTime when) => supervisionShortDate(context, when);
    SacValueRow row(String key, String value) => SacValueRow(
          label: 'supervision.enrollments.$key'.tr(),
          value: value,
        );

    final board = enrollment.board;
    // Full translation keys: these are labels of the board, not role checks.
    SacValueRow seat(String labelKey, SupervisionPersonRef person) =>
        SacValueRow(label: labelKey.tr(), value: person.name);
    final boardRows = [
      if (board.director != null)
        seat('supervision.enrollments.director', board.director!),
      for (final deputy in board.deputies)
        seat('supervision.enrollments.deputy', deputy),
      if (board.secretary != null)
        seat('supervision.enrollments.secretary', board.secretary!),
      if (board.treasurer != null)
        seat('supervision.enrollments.treasurer', board.treasurer!),
      if (board.secretaryTreasurer != null)
        seat(
          'supervision.enrollments.secretary_treasurer',
          board.secretaryTreasurer!,
        ),
    ];

    final operationRows = [
      if (_hasText(enrollment.meetingDays))
        row('meeting_days', enrollment.meetingDays!),
      if (_hasText(enrollment.address)) row('address', enrollment.address!),
      if (enrollment.soulsTarget != null)
        row('souls_target', '${enrollment.soulsTarget}'),
      row(
        'fee',
        enrollment.hasFee && enrollment.feeAmount != null
            ? SacMoney.format(enrollment.feeAmount!)
            : 'supervision.enrollments.fee_none'.tr(),
      ),
    ];

    // Who sent it and who decided, as one quiet line each.
    String line(String labelKey, String? name, DateTime? when) => [
          if (name != null && name.trim().isNotEmpty)
            '${'supervision.enrollments.$labelKey'.tr()} $name',
          if (when != null) date(when),
        ].join(' · ');
    final notes = [
      line(
          'submitted_by', enrollment.submittedBy?.name, enrollment.submittedAt),
      line('reviewed_by', enrollment.reviewedBy?.name, enrollment.reviewedAt),
    ].where((note) => note.isNotEmpty).toList();

    Widget group(String key, List<Widget> rows) => SacGroupedSection(
          label: 'supervision.enrollments.$key'.tr(),
          dividerIndent: 16,
          children: rows,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (enrollment.status == SupervisionEnrollmentStatus.rejected &&
            _hasText(enrollment.decisionReason))
          SupervisionQuote(
            label: 'supervision.enrollments.decision_reason'.tr(),
            text: enrollment.decisionReason!.trim(),
            icon: HugeIcons.strokeRoundedAlertCircle,
            tone: SacTone.error,
          ),
        if (boardRows.isNotEmpty) group('board_title', boardRows),
        group('operation_title', operationRows),
        if (notes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Text(
              notes.join('\n'),
              style: TextStyle(
                fontSize: SacFontSize.bodySmall,
                height: 1.5,
                color: c.textTertiary,
              ),
            ),
          ),
      ],
    );
  }
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
