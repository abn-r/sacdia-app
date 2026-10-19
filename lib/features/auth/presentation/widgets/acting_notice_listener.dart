import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/sac_snack_bar.dart';
import '../providers/acting_providers.dart';

/// Muestra una vez los avisos del modo "actuar por" (p. ej. "ya no tienes
/// acceso a este perfil") encima de cualquier pantalla y los descarta.
///
/// Se monta en el `builder` del `MaterialApp`, por debajo del
/// `ScaffoldMessenger`, para que el aviso sobreviva al cambio de ruta que
/// provoca la vuelta al tutor.
class ActingNoticeListener extends ConsumerWidget {
  const ActingNoticeListener({super.key, required this.child});

  final Widget child;

  static String messageFor(ActingNotice notice) => switch (notice) {
        ActingNotice.accessRevoked => 'errors.acting_for_forbidden'.tr(),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<ActingNotice?>(actingNoticeProvider, (_, notice) {
      if (notice == null) return;
      SacSnackBar.show(context, messageFor(notice), isError: true);
      // Se descarta tras mostrarlo para que no reaparezca.
      ref.read(actingNoticeProvider.notifier).state = null;
    });
    return child;
  }
}
