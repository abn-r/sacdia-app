import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Pantalla única del modo restringido de un adolescente sin tutor verificado.
///
/// Esta versión mínima solo permite salir; el estado, el código para el tutor y
/// la cuenta atrás se añaden en el siguiente paso.
class TeenPendingHomeView extends ConsumerWidget {
  const TeenPendingHomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.sac.background,
      body: SafeArea(
        child: Center(
          child: SacButton.outline(
            text: 'legal_gate.sign_out'.tr(),
            onPressed: () => ref.read(authNotifierProvider.notifier).signOut(),
          ),
        ),
      ),
    );
  }
}
