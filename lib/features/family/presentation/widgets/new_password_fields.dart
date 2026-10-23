import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/sac_text_field.dart';

/// Contraseña + confirmación con la política de contraseñas del registro
/// (mínimo 8, mayúscula, minúscula y número) y su pista siempre visible.
///
/// La usan el asistente de acceso propio y los diálogos de reactivar y
/// restablecer contraseña. Valida dentro de un [Form] del llamador: la
/// contraseña nunca sale de aquí salvo por [password].
class NewPasswordFields extends StatelessWidget {
  const NewPasswordFields({
    super.key,
    required this.passwordController,
    required this.confirmController,
    this.passwordLabel,
    this.confirmLabel,
    this.onSubmitted,
  });

  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final String? passwordLabel;
  final String? confirmLabel;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SacTextField(
          controller: passwordController,
          label: passwordLabel ?? 'family.teen.wizard.password_label'.tr(),
          obscureText: true,
          autocorrect: false,
          prefixIcon: HugeIcons.strokeRoundedLockPassword,
          validator: Validators.validatePassword,
          textInputAction: TextInputAction.next,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 12),
          child: Text(
            'family.teen.wizard.password_policy'.tr(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.sac.textSecondary,
                ),
          ),
        ),
        SacTextField(
          controller: confirmController,
          label: confirmLabel ?? 'family.teen.wizard.confirm_label'.tr(),
          obscureText: true,
          autocorrect: false,
          prefixIcon: HugeIcons.strokeRoundedShieldKey,
          validator: (value) =>
              Validators.validatePasswordMatch(passwordController.text, value),
          textInputAction: TextInputAction.done,
          onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
        ),
      ],
    );
  }
}
