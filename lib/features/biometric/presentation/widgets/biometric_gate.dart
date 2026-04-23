import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/biometric_provider.dart';
import '../views/app_lock_view.dart';

/// Gate de alto nivel que bloquea el árbol de widgets con [AppLockView]
/// cuando biometría está habilitada y la sesión en memoria todavía no
/// ha sido desbloqueada en este cold start.
///
/// Contrato:
/// - OFF o `unlocked=true` → renderea [child] (la app normal).
/// - ON y `unlocked=false` → renderea [AppLockView] por encima.
///
/// Se debe envolver DENTRO de [MaterialApp.router] — lo insertamos vía
/// `builder` para que tenga acceso al contexto con Theme/Localizations.
class BiometricGate extends ConsumerWidget {
  final Widget child;
  const BiometricGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(biometricProvider);
    final locked = state.enabled && !state.unlocked;

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
