import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';

/// Barra de acciones de aprobación/rechazo para evidencias y camporees.
///
/// Muestra un estado de carga mientras la operación está en curso.
/// [onApprove] y [onReject] son callbacks que se llaman con la confirmación
/// del usuario ya obtenida.
enum _ApprovalPending { approve, reject }

class ApprovalActionBar extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final String? approveLabel;
  final String? rejectLabel;

  const ApprovalActionBar({
    super.key,
    required this.isLoading,
    required this.onApprove,
    required this.onReject,
    this.approveLabel,
    this.rejectLabel,
  });

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
    final effectiveApproveLabel =
        widget.approveLabel ?? 'coordinator.actions.approve'.tr();
    final effectiveRejectLabel =
        widget.rejectLabel ?? 'coordinator.actions.reject'.tr();
    final loading = widget.isLoading;
    final approveLoading = loading && _pending == _ApprovalPending.approve;
    final rejectLoading = loading && _pending == _ApprovalPending.reject;

    if (loading && _pending == null) {
      return SizedBox(
        height: 48,
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: SacAccent.of(context).color,
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: SacButton(
            text: effectiveRejectLabel,
            icon: HugeIcons.strokeRoundedCancel01,
            variant: SacButtonVariant.outline,
            fullWidth: true,
            textColor: AppColors.error,
            borderColor: AppColors.error.withValues(alpha: 0.5),
            isLoading: rejectLoading,
            isEnabled: !loading,
            onPressed: loading
                ? null
                : () => _begin(_ApprovalPending.reject, widget.onReject),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SacButton.success(
            text: effectiveApproveLabel,
            icon: HugeIcons.strokeRoundedCheckmarkCircle01,
            isLoading: approveLoading,
            isEnabled: !loading,
            onPressed: loading
                ? null
                : () => _begin(_ApprovalPending.approve, widget.onApprove),
          ),
        ),
      ],
    );
  }
}

/// Muestra el diálogo de aprobación con campo de comentario opcional.
///
/// Retorna [true] si el usuario confirma, [false] o [null] si cancela.
Future<String?> showApproveDialog({
  required BuildContext context,
  required String title,
  required String confirmMessage,
}) async {
  final commentsCtrl = TextEditingController();

  try {
    final confirmed = await SacDialog.present<bool>(
      context,
      builder: (ctx) => SacDialog(
        title: title,
        content: confirmMessage,
        body: SacTextField(
          controller: commentsCtrl,
          label: 'coordinator.actions.comment_label'.tr(),
          hint: 'coordinator.actions.comment_hint'.tr(),
          maxLines: 3,
        ),
        actions: [
          SacDialogAction(
            label: 'coordinator.actions.cancel'.tr(),
            style: SacDialogActionStyle.cancel,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          SacDialogAction(
            label: 'coordinator.actions.approve'.tr(),
            style: SacDialogActionStyle.success,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return null;
    return commentsCtrl.text.trim();
  } finally {
    commentsCtrl.dispose();
  }
}

/// Muestra el diálogo de rechazo con campo de motivo requerido.
///
/// Retorna el motivo de rechazo si el usuario confirma, [null] si cancela.
Future<String?> showRejectDialog({
  required BuildContext context,
  required String title,
  required String confirmMessage,
}) async {
  final reasonCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();

  try {
    final confirmed = await SacDialog.present<bool>(
      context,
      builder: (ctx) => SacDialog(
        title: title,
        content: confirmMessage,
        body: Form(
          key: formKey,
          child: SacTextField(
            controller: reasonCtrl,
            label: 'coordinator.actions.reject_reason_label'.tr(),
            hint: 'coordinator.actions.reject_reason_hint'.tr(),
            maxLines: 3,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'coordinator.actions.reject_reason_required'.tr()
                : null,
          ),
        ),
        actions: [
          SacDialogAction(
            label: 'coordinator.actions.cancel'.tr(),
            style: SacDialogActionStyle.cancel,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          SacDialogAction(
            label: 'coordinator.actions.reject'.tr(),
            style: SacDialogActionStyle.destructive,
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
          ),
        ],
      ),
    );

    if (confirmed != true) return null;
    return reasonCtrl.text.trim();
  } finally {
    reasonCtrl.dispose();
  }
}

// ── Snackbar helper ───────────────────────────────────────────────────────────

void showActionSnackbar(
  BuildContext context, {
  required String message,
  required bool success,
}) {
  if (!context.mounted) return;
  SacSnackBar.show(context, message, isError: !success);
}
