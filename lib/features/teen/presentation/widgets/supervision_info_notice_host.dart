import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/notifications/push_notification_provider.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_dialog.dart';
import '../../../../providers/storage_provider.dart';
import '../../../auth/domain/entities/principal_info.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/acting_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Bandera del dispositivo: la nota de transparencia ya se mostró en esta
/// sesión. No identifica a nadie (es un booleano) y se borra al cerrar sesión
/// para que la siguiente persona de este teléfono también la vea.
const String kSupervisionInfoSeenPrefsKey = 'teen_supervision_info_seen';

/// `true` cuando [next] es el primer estado supervisado con tutor verificado
/// que se ve en esta sesión: el adolescente acaba de quedar vinculado (o inicia
/// sesión ya vinculado) y debe saber qué ve su tutor.
bool shouldShowSupervisionInfo(
  UserEntity? previous,
  UserEntity? next, {
  required bool acting,
  required bool alreadySeen,
}) {
  if (acting || alreadySeen || next == null) return false;
  if (next.mode != AccountMode.teenSupervised) return false;
  // Evita repetirlo en cada refresco: solo en la entrada al modo.
  return previous?.id != next.id ||
      previous?.mode != AccountMode.teenSupervised;
}

/// Muestra una vez, la primera vez que el adolescente entra con un tutor
/// verificado, lo que su tutor puede y no puede ver (FP3-26). Se monta en el
/// `builder` del `MaterialApp`, junto a `FamilyPromptHost`.
class SupervisionInfoNoticeHost extends ConsumerWidget {
  const SupervisionInfoNoticeHost({
    super.key,
    required this.child,
    this.navigatorKey,
    this.delay = const Duration(milliseconds: 600),
  });

  final Widget child;

  /// Navegador raíz donde mostrar el diálogo. Por defecto el del router.
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Espera a que el router termine de llevar al inicio antes de mostrarlo.
  final Duration delay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // El estado inicial también cuenta: una sesión restaurada ya vinculada.
    ref.listen(authNotifierProvider, (previous, next) {
      final prefs = ref.read(sharedPreferencesProvider);
      if (!shouldShowSupervisionInfo(
        previous?.valueOrNull,
        next.valueOrNull,
        acting: ref.read(actingDependentProvider) != null,
        alreadySeen: prefs.getBool(kSupervisionInfoSeenPrefsKey) ?? false,
      )) {
        return;
      }
      // Se marca ya: dos cambios de estado seguidos no abren dos diálogos.
      prefs.setBool(kSupervisionInfoSeenPrefsKey, true);
      Future<void>.delayed(delay, () => _show(ref));
    });
    return child;
  }

  Future<void> _show(WidgetRef ref) async {
    final context = (navigatorKey ?? pushNavigatorKey).currentContext;
    if (context == null || !context.mounted) return;
    // La persona pudo cerrar sesión o dejar de ser supervisada en la espera.
    if (ref.read(authNotifierProvider).valueOrNull?.mode !=
        AccountMode.teenSupervised) {
      return;
    }
    await SacDialog.present<void>(
      context,
      builder: (dialogContext) => SacDialog(
        title: 'teen.info.title'.tr(),
        content: 'teen.info.body'.tr(),
        icon: HugeIcons.strokeRoundedShield01,
        iconColor: dialogContext.sac.text,
        actions: [
          SacDialogAction(
            label: 'teen.info.understood'.tr(),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }
}
