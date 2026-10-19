import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/notifications/push_notification_provider.dart';
import '../../../../core/widgets/sac_dialog.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/acting_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// `true` justo después de que el TUTOR termina su propio post-registro.
///
/// Se dispara en la transición `postRegisterComplete: false -> true` del mismo
/// usuario, sin actuar por nadie: así ocurre una sola vez por post-registro y no
/// en cada arranque. Si el post-registro lo completó un menor (se actúa por él)
/// no se pregunta nada.
bool shouldPromptFamily(
  UserEntity? previous,
  UserEntity? next, {
  required bool acting,
}) {
  if (acting || previous == null || next == null) return false;
  if (previous.id != next.id) return false;
  if (next.actingFor != null) return false;
  return !previous.postRegisterComplete && next.postRegisterComplete;
}

/// Pregunta una vez, tras el post-registro del tutor, si tiene menores a cargo
/// (FP-57). Se monta en el `builder` del `MaterialApp`.
class FamilyPromptHost extends ConsumerWidget {
  const FamilyPromptHost({
    super.key,
    required this.child,
    this.navigatorKey,
    this.delay = const Duration(milliseconds: 600),
  });

  final Widget child;

  /// Navegador raíz donde mostrar el diálogo. Por defecto el del router.
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Espera a que el router termine de llevar al inicio antes de preguntar.
  final Duration delay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authNotifierProvider, (previous, next) {
      final acting = ref.read(actingDependentProvider) != null;
      if (!shouldPromptFamily(
        previous?.valueOrNull,
        next.valueOrNull,
        acting: acting,
      )) {
        return;
      }
      Future<void>.delayed(delay, () => _ask(ref));
    });
    return child;
  }

  Future<void> _ask(WidgetRef ref) async {
    // El usuario pudo cambiar de perfil durante la espera.
    if (ref.read(actingDependentProvider) != null) return;
    final context = (navigatorKey ?? pushNavigatorKey).currentContext;
    if (context == null || !context.mounted) return;

    final wantsToAdd = await SacDialog.show(
      context,
      title: 'family.prompt.title'.tr(),
      content: 'family.prompt.body'.tr(),
      confirmLabel: 'family.prompt.add'.tr(),
      cancelLabel: 'family.prompt.later'.tr(),
      icon: HugeIcons.strokeRoundedUserGroup,
    );
    if (wantsToAdd != true || !context.mounted) return;
    GoRouter.of(context).push(RouteNames.familyAdd);
  }
}
