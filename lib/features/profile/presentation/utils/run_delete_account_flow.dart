import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/social_credential.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sac_dialog.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../auth/domain/entities/delete_account_reauth.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../widgets/delete_account_confirm_dialog.dart';
import 'delete_account_dependents_gate.dart';
import 'delete_account_flow.dart';

/// Flujo completo de «Eliminar cuenta»: primera confirmación, aviso de menores
/// a cargo (FP-66), reautenticación (contraseña o proveedor) y `DELETE
/// /auth/me`.
///
/// Lo usan Ajustes y el menú del post-registro (la guideline 5.1.1(v) de App
/// Store exige poder borrar la cuenta dentro de la app, también antes de
/// terminar el registro). Si el borrado sale bien, la sesión pasa a nula y el
/// router lleva al login; el aviso de éxito se muestra con el mensajero que se
/// capturó antes, porque la pantalla de origen puede desmontarse.
Future<void> runDeleteAccountFlow(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final confirmationWord =
      'profile.settings.delete_account_confirmation_word'.tr();

  final firstConfirmed = await SacDialog.show(
    context,
    title: 'profile.settings.delete_account_title'.tr(),
    content: 'profile.settings.delete_account_first_confirm_body'.tr(),
    confirmLabel: 'profile.settings.delete_account_first_confirm_action'.tr(),
    confirmIsDestructive: true,
  );

  if (firstConfirmed != true || !context.mounted) return;

  // Un tutor con menores a cargo los ve (y acepta qué pasará con cada uno)
  // ANTES de pedir la contraseña; sin menores no hay pasos extra (FP-66).
  final flow = DeleteAccountFlow(
    confirmDependents: ({required bool refresh}) async {
      if (!context.mounted) return DependentsAck.cancelled;
      return confirmDeletionDependents(context, ref, refresh: refresh);
    },
    promptReauth: () => _promptReauth(context, ref, confirmationWord),
    delete: (reauth) => _deleteWithFeedback(context, ref, messenger, reauth),
  );

  final result = await flow.run();
  if (result == null) return;

  if (result.isSuccess) {
    SacSnackBar.showMessenger(
      messenger,
      'profile.settings.account_deleted'.tr(),
      backgroundColor: AppColors.success,
    );
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  } else {
    SacSnackBar.showMessenger(messenger, result.errorMessage!, isError: true);
  }
}

/// Segunda confirmación: palabra de confirmación + contraseña o proveedor.
Future<DeleteAccountReauth?> _promptReauth(
  BuildContext context,
  WidgetRef ref,
  String confirmationWord,
) async {
  // Proveedores vinculados para ofrecer la confirmación sin contraseña.
  // El diálogo muestra solo los que este dispositivo soporta.
  // La consulta puede tardar con mala red: se muestra progreso y se limita
  // a 10 s; si no responde, se sigue solo con la contraseña.
  if (!context.mounted) return null;
  SacSnackBar.show(
    context,
    'common.loading'.tr(),
    duration: const Duration(seconds: 15),
    leading: const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
    ),
  );
  final List<SocialProvider> providers = await ref
      .read(authNotifierProvider.notifier)
      .connectedProviders()
      .timeout(
        const Duration(seconds: 10),
        onTimeout: () => const <SocialProvider>[],
      );
  if (!context.mounted) return null;
  SacSnackBar.hide(context);

  return SacDialog.present<DeleteAccountReauth>(
    context,
    barrierDismissible: false,
    builder: (_) => DeleteAccountConfirmDialog(
      confirmationWord: confirmationWord,
      connectedProviders: providers,
    ),
  );
}

Future<DeleteAccountResult> _deleteWithFeedback(
  BuildContext context,
  WidgetRef ref,
  ScaffoldMessengerState messenger,
  DeleteAccountReauth reauth,
) async {
  if (context.mounted) {
    SacSnackBar.show(
      context,
      'profile.settings.deleting_account'.tr(),
      duration: const Duration(seconds: 30),
      leading: const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      ),
    );
  }

  final result =
      await ref.read(authNotifierProvider.notifier).deleteAccountWithResult(
            reauth,
          );

  SacSnackBar.hideMessenger(messenger);
  return result;
}
