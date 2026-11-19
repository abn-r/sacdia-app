import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/sac_sheet.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../widgets/change_password_sheet.dart';

/// Opens the change-password bottom sheet ([ChangePasswordSheet]) and, once the
/// password changed, shows the success message.
///
/// Lo usan Seguridad (Ajustes) y la pantalla del adolescente sin tutor
/// verificado (que puede cambiar su contraseña: `self:password`). The sheet
/// reads its own `ref`; [ref] is kept so existing callers do not change.
Future<void> runChangePasswordFlow(
  BuildContext context,
  WidgetRef ref,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final changed = await showSacSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const ChangePasswordSheet(),
  );
  if (changed == true) {
    SacSnackBar.showMessenger(
      messenger,
      'profile.settings.password_updated'.tr(),
      isSuccess: true,
    );
  }
}
