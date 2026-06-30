import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/biometric_provider.dart';
import '../views/app_lock_view.dart';

/// Gate de alto nivel que bloquea el árbol de widgets con [AppLockView]
/// cuando hay una sesión autenticada, biometría está habilitada y la sesión
/// en memoria todavía no ha sido desbloqueada en este cold start.
///
/// Contrato:
/// - Sin usuario autenticado → renderea [child] (login/rutas públicas).
/// - OFF o `unlocked=true` → renderea [child] (la app normal).
/// - Usuario autenticado + ON + `unlocked=false` → renderea [AppLockView].
///
/// Se debe envolver DENTRO de [MaterialApp.router] — lo insertamos vía
/// `builder` para que tenga acceso al contexto con Theme/Localizations.
class BiometricGate extends ConsumerWidget {
  final Widget child;
  const BiometricGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final biometricState = ref.watch(biometricProvider);
    final authState = ref.watch(authNotifierProvider);
    final locked = shouldShowBiometricLock(
      biometricState: biometricState,
      isAuthenticated: authState.valueOrNull != null,
    );

    // Stack para mantener al `child` montado detrás y evitar re-inicializar
    // routers/providers cuando el lock se retira.
    return Stack(
      children: [
        child,
        if (locked)
          const Positioned.fill(
            child: AppLockView(),
          ),
      ],
    );
  }
}

bool shouldShowBiometricLock({
  required BiometricState biometricState,
  required bool isAuthenticated,
}) {
  return isAuthenticated && biometricState.enabled && !biometricState.unlocked;
}
