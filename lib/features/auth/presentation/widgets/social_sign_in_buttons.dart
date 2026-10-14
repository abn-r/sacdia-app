import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sacdia_app/core/auth/social_auth_provider.dart';
import 'package:sacdia_app/core/auth/social_credential.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';

/// Separador "o continúa con" + botones de Google y Apple.
///
/// Apple solo aparece en iOS; Google solo cuando hay
/// `GOOGLE_SERVER_CLIENT_ID` (ver `AppConstants.googleServerClientId`).
/// Si ninguno está disponible, no se renderiza nada.
class SocialSignInButtons extends ConsumerStatefulWidget {
  const SocialSignInButtons({super.key, required this.enabled});

  final bool enabled;

  @override
  ConsumerState<SocialSignInButtons> createState() =>
      _SocialSignInButtonsState();
}

class _SocialSignInButtonsState extends ConsumerState<SocialSignInButtons> {
  /// Proveedor con la hoja nativa abierta. El estado global de auth no pasa
  /// por loading durante el login social (desmontaría esta pantalla), así que
  /// el estado de carga y el guard de doble toque viven aquí.
  SocialProvider? _busyProvider;

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(socialAuthClientProvider);
    final providers = SocialProvider.values.where(client.supports).toList();
    if (providers.isEmpty) return const SizedBox.shrink();

    final isBusy = _busyProvider != null;
    final c = context.sac;
    final divider = Theme.of(context).dividerColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: Divider(color: divider)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'auth.or_continue_with'.tr(),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: c.textSecondary),
              ),
            ),
            Expanded(child: Divider(color: divider)),
          ],
        ),
        const SizedBox(height: 16),
        for (final provider in providers) ...[
          _SocialButton(
            provider: provider,
            enabled: widget.enabled && !isBusy,
            isLoading: _busyProvider == provider,
            onPressed: () => _signIn(provider),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Future<void> _signIn(SocialProvider provider) async {
    if (_busyProvider != null) return;
    setState(() => _busyProvider = provider);
    try {
      final notifier = ref.read(authNotifierProvider.notifier);
      await switch (provider) {
        SocialProvider.google => notifier.signInWithGoogle(),
        SocialProvider.apple => notifier.signInWithApple(),
      };
    } finally {
      if (mounted) setState(() => _busyProvider = null);
    }
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.provider,
    required this.enabled,
    required this.isLoading,
    required this.onPressed,
  });

  final SocialProvider provider;
  final bool enabled;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Widget icon = switch (provider) {
      SocialProvider.google => SvgPicture.asset(
          'assets/svg/google_logo.svg',
          width: 20,
          height: 20,
        ),
      // El SVG de Apple es negro: se tiñe con el color de texto para que se
      // vea también en modo oscuro.
      SocialProvider.apple => SvgPicture.asset(
          'assets/svg/apple_logo.svg',
          width: 20,
          height: 20,
          colorFilter: ColorFilter.mode(
            Theme.of(context).colorScheme.onSurface,
            BlendMode.srcIn,
          ),
        ),
    };
    final label = switch (provider) {
      SocialProvider.google => 'auth.continue_with_google'.tr(),
      SocialProvider.apple => 'auth.continue_with_apple'.tr(),
    };
    return SacButton(
      text: label,
      variant: SacButtonVariant.outline,
      size: SacButtonSize.large,
      fullWidth: true,
      borderRadius: AppTheme.radiusFull,
      isEnabled: enabled,
      isLoading: isLoading,
      onPressed: onPressed,
      icon: icon,
    );
  }
}
