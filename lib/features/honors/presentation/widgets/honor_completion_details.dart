import 'package:sacdia_app/core/widgets/sac_date_picker.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/constants/certificate_dates.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/instructor_field.dart';
import 'package:sacdia_app/core/widgets/instructor_selection.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/features/activities/presentation/widgets/activity_form_widgets.dart';

import '../../domain/entities/user_honor.dart';
import '../../domain/entities/user_honor_update.dart';
import '../providers/honors_providers.dart';

bool _sameInstructor(InstructorSelection a, InstructorSelection b) =>
    a.kind == b.kind &&
    (a.isUser ? a.userId == b.userId : a.displayName == b.displayName);

/// Optional "Instructor o instructora" of a honor in progress or rejected
/// (D10). Saves as soon as the member chooses, with `PATCH`; read-only in any
/// other status, where the instructor can no longer be edited here.
class HonorInstructorCard extends ConsumerStatefulWidget {
  const HonorInstructorCard({super.key, required this.userHonor});

  final UserHonor userHonor;

  @override
  ConsumerState<HonorInstructorCard> createState() =>
      _HonorInstructorCardState();
}

class _HonorInstructorCardState extends ConsumerState<HonorInstructorCard> {
  /// What the member just chose. Shown instead of the saved value while the
  /// save and the list refresh are in flight, and kept after it (the list has
  /// no photo for the person).
  InstructorSelection? _pending;
  bool _saving = false;
  String? _error;

  InstructorSelection get _saved =>
      widget.userHonor.instructor ?? const InstructorSelection.none();

  @override
  void didUpdateWidget(HonorInstructorCard old) {
    super.didUpdateWidget(old);
    if (old.userHonor.instructor == widget.userHonor.instructor) return;
    final pending = _pending;
    if (pending != null && !_sameInstructor(pending, _saved)) _pending = null;
  }

  Future<void> _save(InstructorSelection next) async {
    final before = _pending;
    setState(() {
      _pending = next;
      _saving = true;
      _error = null;
    });
    final failure = await ref
        .read(honorEvidenceActionsNotifierProvider.notifier)
        .saveInstructor(
          userId: widget.userHonor.userId,
          honorId: widget.userHonor.honorId,
          instructor: next,
        );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (failure != null) {
        // Back to what was saved; the reason goes on the field.
        _pending = before;
        _error = _messageFor(failure);
      }
    });
    if (failure != null && _error == null) {
      SacSnackBar.show(context, 'instructor.error_generic'.tr(), isError: true);
    }
  }

  String? _messageFor(Failure failure) {
    final code = failure.errorCode;
    if (code == HonorUpdateErrorCode.invalidStatus) {
      // Changed on another device: the list refresh redraws it read-only.
      ref
          .read(honorEvidenceActionsNotifierProvider.notifier)
          .invalidateHonorEvidence(widget.userHonor.honorId);
      return 'honors.evidence.status_changed'.tr();
    }
    return InstructorErrorCode.fieldMessage(code);
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the notifier alive across the awaited save.
    ref.watch(honorEvidenceActionsNotifierProvider);
    return SacCard(
      child: InstructorField(
        selection: _pending ?? _saved,
        errorText: _error,
        readOnly: !widget.userHonor.canSubmit,
        isLoading: _saving,
        onChanged: _save,
      ),
    );
  }
}

/// "Fecha de finalización": required to submit (the app checks it, the API
/// does not yet). Picked between 1960-01-01 and today, saved right away with
/// `PATCH`. Read-only once the honor is under review or approved.
class HonorCompletionDateCard extends ConsumerStatefulWidget {
  const HonorCompletionDateCard({
    super.key,
    required this.userHonor,
    this.clock,
  });

  final UserHonor userHonor;

  /// "Today" for the date rule; tests inject it.
  final DateTime Function()? clock;

  @override
  ConsumerState<HonorCompletionDateCard> createState() =>
      _HonorCompletionDateCardState();
}

class _HonorCompletionDateCardState
    extends ConsumerState<HonorCompletionDateCard> {
  DateTime? _pending;
  bool _saving = false;
  String? _error;

  DateTime get _today => (widget.clock ?? DateTime.now)();
  bool get _editable => widget.userHonor.canSubmit;

  @override
  void didUpdateWidget(HonorCompletionDateCard old) {
    super.didUpdateWidget(old);
    if (old.userHonor.completedAt != widget.userHonor.completedAt) {
      _pending = null;
    }
  }

  /// Editable rows show only what the member set (`date` is when the honor
  /// was started); finished ones fall back to the validation or start date.
  DateTime? get _shown =>
      _pending ??
      (_editable
          ? widget.userHonor.completedAt
          : widget.userHonor.completionDate);

  Future<void> _pick() async {
    final first = kMinCertificateDate;
    final last = CertificateDateRule.lastDate(_today);
    var initial = _shown ?? last;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final picked = await showSacDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      locale: context.locale,
    );
    if (picked == null || !mounted) return;
    await _save(DateTime(picked.year, picked.month, picked.day));
  }

  String? _ruleMessage(DateTime date) =>
      switch (CertificateDateRule.check(date, now: _today)) {
        CertificateDateIssue.tooOld => 'honors.evidence.date_too_old'.tr(),
        CertificateDateIssue.future => 'honors.evidence.date_future'.tr(),
        _ => null,
      };

  Future<void> _save(DateTime date) async {
    final invalid = _ruleMessage(date);
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    final before = _pending;
    setState(() {
      _pending = date;
      _saving = true;
      _error = null;
    });
    final failure = await ref
        .read(honorEvidenceActionsNotifierProvider.notifier)
        .saveCompletedAt(
          userId: widget.userHonor.userId,
          honorId: widget.userHonor.honorId,
          completedAt: date,
        );
    if (!mounted) return;
    String? onField;
    if (failure != null) {
      switch (failure.errorCode) {
        case HonorUpdateErrorCode.dateTooOld:
          onField = 'honors.evidence.date_too_old'.tr();
        case HonorUpdateErrorCode.dateInFuture:
          onField = 'honors.evidence.date_future'.tr();
        case HonorUpdateErrorCode.invalidStatus:
          onField = 'honors.evidence.status_changed'.tr();
          ref
              .read(honorEvidenceActionsNotifierProvider.notifier)
              .invalidateHonorEvidence(widget.userHonor.honorId);
      }
    }
    setState(() {
      _saving = false;
      if (failure != null) {
        _pending = before;
        _error = onField;
      }
    });
    if (failure != null && onField == null) {
      SacSnackBar.show(context, 'honors.evidence.date_save_error'.tr(),
          isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(honorEvidenceActionsNotifierProvider);
    final c = context.sac;
    final theme = Theme.of(context).textTheme;
    final date = _shown;
    final title = 'honors.evidence.completion_date_title'.tr();
    final note = _error ??
        (_editable && date == null
            ? 'honors.evidence.completion_date_required'.tr()
            : null);

    return SacCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: _editable,
            enabled: _editable && !_saving,
            excludeSemantics: true,
            label: date == null
                ? title
                : '$title: ${DateFormat.yMMMMd(Localizations.localeOf(context).toString()).format(date)}',
            onTap: _editable && !_saving ? _pick : null,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 160),
              opacity: _saving ? 0.6 : 1,
              child: ActivityDatePickerField(
                label: title,
                value: date,
                enabled: _editable && !_saving,
                // Approved or in review: the date is frozen, nothing to open.
                showChevron: _editable,
                onTap: _pick,
              ),
            ),
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  note,
                  style: theme.bodySmall?.copyWith(
                    color: _error != null ? c.error : c.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
