import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../domain/utils/authorization_utils.dart';
import '../providers/auth_providers.dart';

/// Destino de una cuenta cuyo `onboarding_mode` es `panel_only`: su función se
/// hace en el panel web y la app no tiene tareas para ella.
///
/// No es un error ni un bloqueo: la cuenta está activa. La pantalla lo explica
/// y deja tres salidas, de más a menos útil:
///
/// - «Mi familia», solo si la cuenta es de tutor: es lo único que puede hacer
///   aquí, así que es la acción principal.
/// - «Comprobar de nuevo»: vuelve a pedir `/auth/me`. Si el servidor cambió el
///   modo (le asignaron un club o una función con superficie en la app), el
///   router la saca de aquí; si no, el texto de ayuda lo dice en el mismo sitio.
/// - «Cerrar sesión», discreta, como en [RestrictedAccountView].
///
/// El modo lo decide el servidor: esta vista no mira roles ni clubes.
class PanelOnlyAccountView extends ConsumerStatefulWidget {
  const PanelOnlyAccountView({super.key});

  @override
  ConsumerState<PanelOnlyAccountView> createState() =>
      _PanelOnlyAccountViewState();
}

class _PanelOnlyAccountViewState extends ConsumerState<PanelOnlyAccountView> {
  bool _checking = false;

  /// La última comprobación terminó sin cambios (o sin poder leer el servidor:
  /// para quien mira la pantalla es lo mismo, nada cambió todavía).
  bool _unchanged = false;

  Future<void> _checkAgain() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _unchanged = false;
    });
    var changed = false;
    try {
      changed = await ref
          .read(authNotifierProvider.notifier)
          .refreshAuthorization(minInterval: Duration.zero);
    } catch (_) {
      changed = false;
    }
    // Si cambió, el router ya está llevando la cuenta a su inicio.
    if (!mounted) return;
    setState(() {
      _checking = false;
      _unchanged = !changed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    final textTheme = Theme.of(context).textTheme;
    final user = ref.watch(authNotifierProvider).value;
    final isGuardian = isGuardianAccount(user);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: Responsive.formPadding(context),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: Responsive.maxFormWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: ExcludeSemantics(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: accent.color.withValues(alpha: 0.14),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMD),
                          ),
                          alignment: Alignment.center,
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedLaptop,
                            size: 28,
                            color: accent.color,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Semantics(
                      header: true,
                      child: Text(
                        'panel_only_account.title'.tr(),
                        textAlign: TextAlign.center,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          height: 1.2,
                          color: c.text,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'panel_only_account.body'.tr(),
                      textAlign: TextAlign.center,
                      style: textTheme.bodyLarge?.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                    if (isGuardian) ...[
                      const SizedBox(height: 8),
                      Text(
                        'panel_only_account.family_hint'.tr(),
                        key: const ValueKey('panel_only_family_hint'),
                        textAlign: TextAlign.center,
                        style: textTheme.bodyLarge?.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (isGuardian) ...[
                      SacButton(
                        key: const ValueKey('panel_only_family'),
                        text: 'family.title'.tr(),
                        icon: HugeIcons.strokeRoundedUserGroup,
                        variant: SacButtonVariant.primary,
                        size: SacButtonSize.large,
                        fullWidth: true,
                        borderRadius: AppTheme.radiusFull,
                        onPressed: () => context.push(RouteNames.family),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SacButton(
                      key: const ValueKey('panel_only_check'),
                      text: 'panel_only_account.check_again'.tr(),
                      icon: HugeIcons.strokeRoundedRefresh,
                      variant: SacButtonVariant.outline,
                      size: SacButtonSize.large,
                      fullWidth: true,
                      borderRadius: AppTheme.radiusFull,
                      isLoading: _checking,
                      loadingSemanticLabel: 'panel_only_account.checking'.tr(),
                      onPressed: _checkAgain,
                    ),
                    const SizedBox(height: 10),
                    // El resultado ocupa el lugar de la ayuda: nada se mueve
                    // al terminar la comprobación.
                    Semantics(
                      liveRegion: true,
                      child: AnimatedSwitcher(
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 200),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: Text(
                          _unchanged
                              ? 'panel_only_account.unchanged'.tr()
                              : 'panel_only_account.check_hint'.tr(),
                          key: ValueKey(
                            _unchanged
                                ? 'panel_only_unchanged'
                                : 'panel_only_check_hint',
                          ),
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall?.copyWith(
                            color: c.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SacButton.ghost(
                      key: const ValueKey('panel_only_sign_out'),
                      text: 'legal_gate.sign_out'.tr(),
                      icon: HugeIcons.strokeRoundedLogout02,
                      textColor: AppColors.error,
                      onPressed: () =>
                          ref.read(authNotifierProvider.notifier).signOut(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
