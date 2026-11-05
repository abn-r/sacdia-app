import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/widgets/instructor_field.dart';
import 'package:sacdia_app/core/widgets/instructor_selection.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';

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
