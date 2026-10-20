import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../features/auth/domain/entities/user_entity.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/family/domain/entities/dependent.dart';
import '../../features/family/presentation/providers/family_providers.dart';
import '../auth/acting_for_session.dart';
import '../utils/app_logger.dart';
import '../widgets/sac_dialog.dart';
import '../widgets/sac_snack_bar.dart';

/// Toque en una notificación que el servidor reenvió al tutor en nombre de un
/// menor (`data.dependent_user_id`, título "Ana · ...") (FP-64).
///
/// Orden:
/// 1. Espera a que cargue la sesión del tutor (arranque en frío desde el push).
/// 2. Comprueba que el menor sigue en la lista de ESTE tutor
///    (`GET /guardianships/me/dependents`, siempre sin `X-Acting-For`) y no está
///    congelado. Si no: no se cambia de perfil y se avisa. El id del payload
///    nunca se usa para actuar: solo se compara; el cambio usa el id de la
///    lista.
/// 3. Pregunta "Esta notificación es de Ana. ¿Cambiar a su perfil?". Aceptar =
///    `switchProfile` + navegación; cancelar no hace nada.
class DependentPushTapHandler {
  DependentPushTapHandler({
    required Ref ref,
    required GlobalKey<NavigatorState>? navigatorKey,
    this.sessionTimeout = const Duration(seconds: 20),
    this.lookupTimeout = const Duration(seconds: 10),
  })  : _ref = ref,
        _navigatorKey = navigatorKey;

  static const _tag = 'DependentPushTap';

  final Ref _ref;
  final GlobalKey<NavigatorState>? _navigatorKey;

  /// Cuánto se espera a que cargue la sesión (arranque en frío).
  final Duration sessionTimeout;

  /// Cuánto se espera a la lista de menores.
  final Duration lookupTimeout;

  bool _busy = false;

  /// Id del menor del payload, o `null` si no es un push de dependiente.
  static String? dependentIdOf(Map<String, dynamic> data) {
    final raw = data['dependent_user_id']?.toString().trim();
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  /// Atiende el toque. [onReady] se llama cuando ya se actúa por el menor (o ya
  /// se actuaba) y hay que ir al destino del push.
  Future<void> handle(String dependentId,
      {required VoidCallback onReady}) async {
    if (_busy) return;
    _busy = true;
    try {
      await _handle(dependentId, onReady);
    } catch (e, st) {
      AppLogger.e('Fallo al atender push de dependiente',
          tag: _tag, error: e, stackTrace: st);
    } finally {
      _busy = false;
    }
  }

  Future<void> _handle(String dependentId, VoidCallback onReady) async {
    final guardian = await _awaitSession();
    if (guardian == null) return; // sin sesión: el router lleva al login

    // Ya se actúa por este menor: no hay nada que preguntar.
    if (_ref.read(actingForSessionProvider).dependentUserId == dependentId) {
      onReady();
      return;
    }

    final dependent = await _findActableDependent(dependentId);
    if (dependent == null) {
      _showSnack('family.push.unavailable'.tr());
      return;
    }

    final context = _navigatorKey?.currentContext;
    if (context == null || !context.mounted) return;

    final accepted = await SacDialog.show(
      context,
      title: 'family.push.dialog_title'.tr(
        namedArgs: {'name': dependent.firstName},
      ),
      content: 'family.push.dialog_body'.tr(
        namedArgs: {'name': dependent.firstName},
      ),
      confirmLabel: 'family.push.dialog_confirm'.tr(),
      cancelLabel: 'family.push.dialog_cancel'.tr(),
      icon: HugeIcons.strokeRoundedUserGroup,
    );
    if (accepted != true) return;

    final outcome = await _ref
        .read(authNotifierProvider.notifier)
        .switchProfile(dependent.userId, firstName: dependent.firstName);

    switch (outcome) {
      case SwitchProfileOutcome.entered:
      case SwitchProfileOutcome.unchanged:
        onReady();
      case SwitchProfileOutcome.offline:
        _showSnack('family.switch.offline'.tr(), isError: true);
      case SwitchProfileOutcome.failed:
        _showSnack('family.switch.failed'.tr(), isError: true);
      case SwitchProfileOutcome.accessRevoked:
        // Lo avisa el listener global de ACTING_FOR_FORBIDDEN.
        break;
      case SwitchProfileOutcome.superseded:
      case SwitchProfileOutcome.exited:
        break;
    }
  }

  /// Espera a que `AuthNotifier` deje de cargar. `null` si no hay sesión o no
  /// cargó a tiempo. Lo usa también el toque de un push de familia para decidir
  /// según el modo de la sesión (arranque en frío).
  Future<UserEntity?> awaitSession() => _awaitSession();

  Future<UserEntity?> _awaitSession() async {
    final completer = Completer<UserEntity?>();
    final sub = _ref.listen<AsyncValue<UserEntity?>>(
      authNotifierProvider,
      (_, next) {
        if (!next.isLoading && !completer.isCompleted) {
          completer.complete(next.valueOrNull);
        }
      },
      fireImmediately: true,
    );
    try {
      return await completer.future.timeout(
        sessionTimeout,
        onTimeout: () => null,
      );
    } finally {
      sub.close();
    }
  }

  /// El menor de [dependentId] en la lista fresca del tutor, o `null` si no
  /// está, está congelado o la consulta falla.
  Future<DependentSummary?> _findActableDependent(String dependentId) async {
    try {
      _ref.invalidate(dependentsProvider);
      final overview =
          await _ref.read(dependentsProvider.future).timeout(lookupTimeout);
      for (final dependent in overview.actable) {
        if (dependent.userId == dependentId) return dependent;
      }
    } catch (e) {
      AppLogger.w('No se pudo consultar los menores', tag: _tag, error: e);
    }
    return null;
  }

  void _showSnack(String message, {bool isError = false}) {
    final context = _navigatorKey?.currentContext;
    if (context == null || !context.mounted) return;
    SacSnackBar.show(context, message, isError: isError);
  }
}
