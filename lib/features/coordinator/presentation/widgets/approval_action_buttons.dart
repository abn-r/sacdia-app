import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
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
  final String approveLabel;
  final String rejectLabel;

  const ApprovalActionBar({
    super.key,
    required this.isLoading,
    required this.onApprove,
    required this.onReject,
    this.approveLabel = 'Aprobar',
    this.rejectLabel = 'Rechazar',
  });

  @override
  Widget build(BuildContext context) {
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
        // ── Reject ─────────────────────────────────────────────────────────
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onReject,
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedCancel01,
              size: 16,
              color: AppColors.error,
            ),
            label: Text(
              rejectLabel,
              style: const TextStyle(color: AppColors.error),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // ── Approve ────────────────────────────────────────────────────────
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onApprove,
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedCheckmarkCircle01,
              size: 16,
              color: Colors.white,
            ),
            label: Text(approveLabel),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
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

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(confirmMessage, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 16),
          TextField(
            controller: commentsCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Comentario (opcional)',
              hintText: 'Ej: Documentación completa y correcta',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Aprobar'),
        ),
      ],
    ),
  );

  if (confirmed != true) return null;
  return commentsCtrl.text.trim();
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

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(confirmMessage, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            TextFormField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Motivo del rechazo *',
                hintText: 'Es obligatorio indicar el motivo',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty)
                      ? 'El motivo es obligatorio'
                      : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.pop(ctx, true);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
          ),
          child: const Text('Rechazar'),
        ),
      ],
    ),
  );

  if (confirmed != true) return null;
  return reasonCtrl.text.trim();
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
