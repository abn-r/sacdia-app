import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/widgets/sac_dialog.dart';
import 'new_password_fields.dart';

/// Pide al tutor una contraseña nueva (reactivar o restablecer el acceso de un
/// menor con usuario). Devuelve la contraseña ya validada contra la política y
/// confirmada, o `null` si cancela.
///
/// La contraseña solo vive en los controladores de este diálogo, que se
/// liberan al cerrar: no se guarda, no se registra y no se devuelve a nadie
/// más que al llamador.
Future<String?> showNewPasswordDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  List<List<dynamic>>? icon,
}) {
  return SacDialog.present<String>(
    context,
    builder: (dialogContext) => _NewPasswordDialog(
      title: title,
      body: body,
      confirmLabel: confirmLabel,
      icon: icon ?? HugeIcons.strokeRoundedLockPassword,
    ),
  );
}

class _NewPasswordDialog extends StatefulWidget {
  const _NewPasswordDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.icon,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final List<List<dynamic>> icon;

  @override
  State<_NewPasswordDialog> createState() => _NewPasswordDialogState();
}

class _NewPasswordDialogState extends State<_NewPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.of(context).pop(_password.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return SacDialog(
      title: widget.title,
      content: widget.body,
      icon: widget.icon,
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: NewPasswordFields(
            passwordController: _password,
            confirmController: _confirm,
            passwordLabel: 'family.access.new_password'.tr(),
            onSubmitted: _submit,
          ),
        ),
      ),
      actions: [
        SacDialogAction(
          label: 'common.cancel'.tr(),
          style: SacDialogActionStyle.cancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        SacDialogAction(label: widget.confirmLabel, onPressed: _submit),
      ],
    );
  }
}
