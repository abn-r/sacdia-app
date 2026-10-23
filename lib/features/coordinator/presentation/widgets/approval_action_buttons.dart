import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';

enum _ApprovalPending { approve, reject }

/// Sticky reject / approve bar of the evidence detail.
///
/// Sits at the bottom of the screen inside the safe area with a hairline on
/// top. Both buttons are at least 48 pt tall; the pressed one shows the loading
/// state while the other stays disabled. [onApprove] and [onReject] are called
/// on tap; the confirmation (dialog or sheet) is the caller's job.

/// Backend limits (ApproveEvidenceDto.comments / RejectEvidenceDto.reason).
const int kApproveCommentMaxLength = 500;
const int kRejectReasonMaxLength = 1000;

class ApprovalActionBar extends StatefulWidget {
  const ApprovalActionBar({
    super.key,
    required this.isLoading,
    required this.onApprove,
    required this.onReject,
    this.approveLabel,
    this.rejectLabel,
  });

  final bool isLoading;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final String? approveLabel;
  final String? rejectLabel;

  /// Equal widths: at 5:7 the reject label ("Rechazar" plus its icon)
  /// truncated on a 402pt-wide iPhone. Approve stands out by its fill, not
  /// its width.
  static const int rejectFlex = 1;
  static const int approveFlex = 1;

  @override
  State<ApprovalActionBar> createState() => _ApprovalActionBarState();
}

class _ApprovalActionBarState extends State<ApprovalActionBar> {
  _ApprovalPending? _pending;

  @override
  void didUpdateWidget(covariant ApprovalActionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLoading && !widget.isLoading) {
      _pending = null;
    }
  }

  void _begin(_ApprovalPending which, VoidCallback action) {
    _pending = which;
    action();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final hPad = Responsive.horizontalPadding(context);
    final approveLabel =
        widget.approveLabel ?? 'coordinator.actions.approve'.tr();
    final rejectLabel = widget.rejectLabel ?? 'coordinator.actions.reject'.tr();
    final loading = widget.isLoading;
    final approveLoading = loading && _pending == _ApprovalPending.approve;
    final rejectLoading = loading && _pending == _ApprovalPending.reject;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 12),
          child: Row(
            children: [
              Expanded(
                flex: ApprovalActionBar.rejectFlex,
                child: SacButton.outline(
                  text: rejectLabel,
                  icon: HugeIcons.strokeRoundedCancel01,
                  textColor: c.error,
                  borderColor: c.error.withValues(alpha: 0.5),
                  isLoading: rejectLoading,
                  isEnabled: !loading,
                  onPressed: loading
                      ? null
                      : () => _begin(_ApprovalPending.reject, widget.onReject),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: ApprovalActionBar.approveFlex,
                child: SacButton.success(
                  text: approveLabel,
                  icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                  isLoading: approveLoading,
                  isEnabled: !loading,
                  onPressed: loading
                      ? null
                      : () =>
                          _begin(_ApprovalPending.approve, widget.onApprove),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Approve confirmation ──────────────────────────────────────────────────────

/// Asks the coordinator to confirm an approval, with an optional comment.
///
/// Returns `null` when the user cancels or dismisses, and the trimmed comment
/// (empty when none was written) when they confirm. Callers must stop on `null`.
Future<String?> showApproveDialog({
  required BuildContext context,
  required String title,
  required String confirmMessage,
}) {
  return SacDialog.present<String>(
    context,
    builder: (_) => _ApproveDialog(title: title, message: confirmMessage),
  );
}

class _ApproveDialog extends StatefulWidget {
  const _ApproveDialog({required this.title, required this.message});

  final String title;
  final String message;

  @override
  State<_ApproveDialog> createState() => _ApproveDialogState();
}

class _ApproveDialogState extends State<_ApproveDialog> {
  final _commentCtrl = TextEditingController();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SacDialog(
      title: widget.title,
      content: widget.message,
      body: SacTextField(
        controller: _commentCtrl,
        label: 'coordinator.actions.comment_label'.tr(),
        hint: 'coordinator.actions.comment_hint'.tr(),
        maxLines: 3,
        maxLength: kApproveCommentMaxLength,
        textCapitalization: TextCapitalization.sentences,
      ),
      actions: [
        SacDialogAction(
          label: 'coordinator.actions.cancel'.tr(),
          style: SacDialogActionStyle.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        SacDialogAction(
          label: 'coordinator.actions.approve'.tr(),
          style: SacDialogActionStyle.success,
          onPressed: () => Navigator.pop(context, _commentCtrl.text.trim()),
        ),
      ],
    );
  }
}

// ── Reject sheet ──────────────────────────────────────────────────────────────

/// Bottom sheet that collects the (required) rejection reason.
///
/// Keyboard-safe. Returns the trimmed reason when the user confirms and `null`
/// when they cancel or dismiss. An empty reason shows an inline error and does
/// not close the sheet.
Future<String?> showRejectSheet({
  required BuildContext context,
  required String title,
  required String message,
}) {
  return showSacSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _RejectSheet(title: title, message: message),
  );
}

class _RejectSheet extends StatefulWidget {
  const _RejectSheet({required this.title, required this.message});

  final String title;
  final String message;

  @override
  State<_RejectSheet> createState() => _RejectSheetState();
}

class _RejectSheetState extends State<_RejectSheet> {
  final _reasonCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.pop(context, _reasonCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SacSheetHeader(title: widget.title, subtitle: widget.message),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Form(
                      key: _formKey,
                      child: SacTextField(
                        controller: _reasonCtrl,
                        label: 'coordinator.actions.reject_reason_label'.tr(),
                        hint: 'coordinator.actions.reject_reason_hint'.tr(),
                        maxLines: 4,
                        maxLength: kRejectReasonMaxLength,
                        textCapitalization: TextCapitalization.sentences,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'coordinator.actions.reject_reason_required'.tr()
                            : null,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: SacButton.outline(
                            text: 'coordinator.actions.cancel'.tr(),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SacButton.destructive(
                            text: 'coordinator.actions.reject'.tr(),
                            icon: HugeIcons.strokeRoundedCancel01,
                            onPressed: _confirm,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
