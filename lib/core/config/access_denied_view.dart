import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../widgets/sac_button.dart';
import '../widgets/sac_error_state.dart';
import 'route_names.dart';

/// Destino del guard de rutas (`routeScreenIds` + `canViewScreen`) cuando el
/// usuario abre, por enlace profundo, push o navegación, una pantalla del
/// catálogo que su autorización no permite.
///
/// Es la misma pieza que muestran las vistas ante un 403 del servidor
/// (`SacErrorState.forbidden`), con una sola acción: volver al inicio por
/// splash, que lleva a cada modo de sesión (cuenta, adolescente, teléfono
/// vinculado, actuando por un menor) a su propio inicio. La ruta negada no se
/// muestra ni se registra: un enlace puede llevar un token.
class AccessDeniedView extends StatelessWidget {
  const AccessDeniedView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SacErrorState.forbidden(padding: EdgeInsets.zero),
                const SizedBox(height: 24),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: SacButton.primary(
                    text: 'router.access_denied.action'.tr(),
                    icon: HugeIcons.strokeRoundedHome01,
                    onPressed: () => context.go(RouteNames.splash),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
