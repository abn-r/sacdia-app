import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/animations/page_transitions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../profile/presentation/utils/run_delete_account_flow.dart';
import '../../../profile/presentation/views/data_export_view.dart';

/// Salidas de la persona liberada: exportar sus datos, borrar su cuenta y
/// cerrar sesión. Siempre disponibles, también congelada (la compuerta del
/// servidor deja pasar `data:export` y `account:manage`).
///
/// Las dos primeras reutilizan los flujos de Ajustes (`DataExportView` y
/// `runDeleteAccountFlow`). Aquí nunca se dice que la cuenta se borrará sola:
/// no es así (R6), solo la borra la propia persona.
class ReleaseAccountActions extends ConsumerWidget {
  const ReleaseAccountActions({super.key, this.enabled = true});

  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SacButton.outline(
          key: const ValueKey('release_export_data'),
          text: 'release.actions.export'.tr(),
          icon: HugeIcons.strokeRoundedDownload02,
          isEnabled: enabled,
          onPressed: () => Navigator.of(context).push(
            SacSharedAxisRoute(builder: (_) => const DataExportView()),
          ),
        ),
        const SizedBox(height: 4),
        SacButton.ghost(
          key: const ValueKey('release_delete_account'),
          text: 'release.actions.delete'.tr(),
          icon: HugeIcons.strokeRoundedDelete02,
          textColor: AppColors.error,
          isEnabled: enabled,
          onPressed: () => runDeleteAccountFlow(context, ref),
        ),
        SacButton.ghost(
          key: const ValueKey('release_sign_out'),
          text: 'legal_gate.sign_out'.tr(),
          icon: HugeIcons.strokeRoundedLogout02,
          isEnabled: enabled,
          onPressed: () => ref.read(authNotifierProvider.notifier).signOut(),
        ),
      ],
    );
  }
}
