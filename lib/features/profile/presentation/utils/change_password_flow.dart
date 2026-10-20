import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../../core/widgets/sac_text_field.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../biometric/presentation/providers/biometric_provider.dart';

/// Diálogo de cambio de contraseña con su flujo completo: pide la actual y la
/// nueva, confirma con biometría si está activada y llama a
/// `POST /auth/update-password`.
///
/// Lo usan Ajustes y la pantalla del adolescente sin tutor verificado (que
/// puede cambiar su contraseña: `self:password`).
Future<void> runChangePasswordFlow(
  BuildContext context,
  WidgetRef ref,
) async {
  final currentCtrl = TextEditingController();
  final newCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  String? errorText;

  final submitted = await showDialog<bool>(
    context: context,
    barrierColor: context.sac.barrierColor,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          void submit() {
            final current = currentCtrl.text.trim();
            final next = newCtrl.text.trim();
            final confirm = confirmCtrl.text.trim();

            if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
              setDialogState(
                  () => errorText = 'profile.settings.error_fill_all'.tr());
              return;
            }
            if (next != confirm) {
              setDialogState(() =>
                  errorText = 'profile.settings.error_passwords_mismatch'.tr());
              return;
            }
            if (next.length < 8) {
              setDialogState(() =>
                  errorText = 'profile.settings.error_password_too_short'.tr());
              return;
            }
            setDialogState(() => errorText = null);
            Navigator.pop(ctx, true);
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              decoration: BoxDecoration(
                color: ctx.sac.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: ctx.sac.border),
                boxShadow: [
                  BoxShadow(
                    color: ctx.sac.shadow,
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: ctx.sac.surfaceVariant,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: ctx.sac.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedLockPassword,
                            color: SacAccent.of(context).color,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'profile.settings.change_password_dialog_title'
                                .tr(),
                            style: TextStyle(
                              color: ctx.sac.text,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SacTextField(
                    controller: currentCtrl,
                    label: 'profile.settings.field_current_password'.tr(),
                    obscureText: true,
                    prefixIcon: HugeIcons.strokeRoundedLockKey,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  SacTextField(
                    controller: newCtrl,
                    label: 'profile.settings.field_new_password'.tr(),
                    obscureText: true,
                    prefixIcon: HugeIcons.strokeRoundedLockPassword,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  SacTextField(
                    controller: confirmCtrl,
                    label: 'profile.settings.field_confirm_password'.tr(),
                    obscureText: true,
                    prefixIcon: HugeIcons.strokeRoundedShieldKey,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => submit(),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        errorText!,
                        style: const TextStyle(
                          color: AppColors.errorDark,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SacButton.primary(
                    text: 'profile.settings.action_change'.tr(),
                    icon: HugeIcons.strokeRoundedTick02,
                    borderRadius: 999,
                    onPressed: submit,
                  ),
                  const SizedBox(height: 8),
                  SacPressable(
                    listenOnly: true,
                    child: TextButton(
                      style: const ButtonStyle(enableFeedback: false),
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text('common.cancel'.tr()),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  if (submitted != true || !context.mounted) {
    currentCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();
    return;
  }

  // Confirmación biométrica antes de cambiar la contraseña
  // (no-op si el usuario no tiene biometría habilitada).
  final bioOk = await requireBiometricConfirmation(
    context,
    ref,
    reason: 'biometric.confirm_sensitive_action'.tr(),
  );
  if (!context.mounted) {
    currentCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();
    return;
  }
  if (!bioOk) {
    currentCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();
    SacSnackBar.show(context, 'profile.settings.operation_cancelled'.tr(),
        isError: true);
    return;
  }

  final error = await ref.read(authNotifierProvider.notifier).updatePassword(
        currentPassword: currentCtrl.text.trim(),
        newPassword: newCtrl.text.trim(),
      );

  currentCtrl.dispose();
  newCtrl.dispose();
  confirmCtrl.dispose();

  if (!context.mounted) return;
  SacSnackBar.show(
    context,
    error ?? 'profile.settings.password_updated'.tr(),
    isError: error != null,
  );
}
