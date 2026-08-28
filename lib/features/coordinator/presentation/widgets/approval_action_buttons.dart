import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import '../../../../core/theme/app_colors.dart';

/// Barra de acciones de aprobación/rechazo para evidencias y camporees.
///
/// Muestra un estado de carga mientras la operación está en curso.
/// [onApprove] y [onReject] son callbacks que se llaman con la confirmación
/// del usuario ya obtenida.
class ApprovalActionBar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final effectiveApproveLabel =
        approveLabel ?? 'coordinator.actions.approve'.tr();
    final effectiveRejectLabel =
        rejectLabel ?? 'coordinator.actions.reject'.tr();

    if (isLoading) {
      return const SizedBox(
        height: 48,
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.primary,
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
            onPressed: onReject,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SacButton.success(
            text: effectiveApproveLabel,
            icon: HugeIcons.strokeRoundedCheckmarkCircle01,
            onPressed: onApprove,
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
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: success ? AppColors.secondary : AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}
