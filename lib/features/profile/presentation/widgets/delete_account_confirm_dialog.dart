import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/auth/social_auth_client.dart';
import 'package:sacdia_app/core/auth/social_auth_provider.dart';
import 'package:sacdia_app/core/auth/social_credential.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';
import 'package:sacdia_app/features/auth/domain/entities/delete_account_reauth.dart';

/// Segunda confirmación del borrado de cuenta: el usuario escribe la palabra
/// de confirmación y se reautentica con su contraseña o, si la cuenta tiene un
/// proveedor vinculado disponible en este dispositivo, con Google/Apple.
///
/// Se cierra con un [DeleteAccountReauth] o con `null` si cancela.
class DeleteAccountConfirmDialog extends ConsumerStatefulWidget {
  const DeleteAccountConfirmDialog({
    super.key,
    required this.confirmationWord,
    this.connectedProviders = const [],
  });

  final String confirmationWord;

  /// Proveedores vinculados a la cuenta. Solo se ofrecen los que el
  /// dispositivo soporta (`SocialAuthClient.supports`): Apple no aparece en
  /// Android y Google no aparece si faltan sus dart-defines.
  final List<SocialProvider> connectedProviders;

  @override
  ConsumerState<DeleteAccountConfirmDialog> createState() =>
      _DeleteAccountConfirmDialogState();
}

class _DeleteAccountConfirmDialogState
    extends ConsumerState<DeleteAccountConfirmDialog> {
  late final TextEditingController _confirmCtrl;
  late final TextEditingController _passwordCtrl;
  String? _fieldError;

  /// Proveedor con la hoja nativa abierta. Evita dobles toques y bloquea la
  /// acción destructiva mientras el SDK está en pantalla.
  SocialProvider? _busyProvider;

  bool get _busy => _busyProvider != null;

  @override
  void initState() {
    super.initState();
    _confirmCtrl = TextEditingController();
    _passwordCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _confirmCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool _confirmationTyped() {
    if (_confirmCtrl.text.trim() == widget.confirmationWord.toUpperCase()) {
      return true;
    }
    setState(() {
      _fieldError = 'profile.settings.delete_account_error_type_wrong'.tr(
        namedArgs: {'word': widget.confirmationWord},
      );
    });
    return false;
  }

  void _submit(List<SocialProvider> providers) {
    if (_busy || !_confirmationTyped()) return;
    final password = _passwordCtrl.text.trim();
    if (password.isEmpty) {
      setState(() {
        _fieldError = providers.isEmpty
            ? 'profile.settings.delete_account_error_no_password'.tr()
            : 'profile.settings.delete_account_error_no_reauth'.tr();
      });
      return;
    }
    Navigator.of(context).pop(PasswordReauth(password));
  }

  Future<void> _confirmWith(SocialProvider provider) async {
    if (_busy || !_confirmationTyped()) return;
    setState(() {
      _fieldError = null;
      _busyProvider = provider;
    });
    try {
      final credential =
          await ref.read(socialAuthClientProvider).signIn(provider);
      // Cancelado en la hoja nativa: se queda en el diálogo, sin error.
      if (!mounted || credential == null) return;
      Navigator.of(context).pop(SocialReauth(credential));
    } on SocialAuthException {
      if (!mounted) return;
      setState(() {
        _fieldError = 'errors.social_signin_failed'.tr(
          namedArgs: {'provider': _label(provider)},
        );
      });
    } finally {
      if (mounted) setState(() => _busyProvider = null);
    }
  }

  static String _label(SocialProvider provider) => switch (provider) {
        SocialProvider.google => 'Google',
        SocialProvider.apple => 'Apple',
      };

  Widget _icon(SocialProvider provider, BuildContext context) =>
      switch (provider) {
        SocialProvider.google => SvgPicture.asset(
            'assets/svg/google_logo.svg',
            width: 18,
            height: 18,
          ),
        // El SVG de Apple es negro: se tiñe para que se vea en modo oscuro.
        SocialProvider.apple => SvgPicture.asset(
            'assets/svg/apple_logo.svg',
            width: 18,
            height: 18,
            colorFilter: ColorFilter.mode(
              Theme.of(context).colorScheme.onSurface,
              BlendMode.srcIn,
            ),
          ),
      };

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final client = ref.watch(socialAuthClientProvider);
    final providers = widget.connectedProviders.where(client.supports).toList();

    return PopScope(
      canPop: !_busy,
      child: SacDialog(
        title: 'profile.settings.delete_account_second_title'.tr(),
        icon: HugeIcons.strokeRoundedAlert02,
        iconColor: AppColors.error,
        iconBackgroundColor: AppColors.errorLight,
        content: 'profile.settings.delete_account_write_eliminate'.tr(
          namedArgs: {'word': widget.confirmationWord},
        ),
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SacTextField(
              controller: _confirmCtrl,
              hint: widget.confirmationWord,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                TextInputFormatter.withFunction(
                  (old, val) => val.copyWith(
                    text: val.text.toUpperCase(),
                    selection: val.selection,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'profile.settings.delete_account_enter_password'.tr(),
              style: TextStyle(fontSize: 14, color: c.textSecondary),
            ),
            const SizedBox(height: 8),
            SacTextField(
              controller: _passwordCtrl,
              hint: 'profile.settings.field_password_hint'.tr(),
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(providers),
            ),
            if (providers.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'profile.settings.delete_account_or_confirm_with'.tr(),
                style: TextStyle(fontSize: 14, color: c.textSecondary),
              ),
              const SizedBox(height: 8),
              for (final provider in providers) ...[
                SacButton(
                  text:
                      'profile.settings.delete_account_confirm_${provider.wireName}'
                          .tr(),
                  variant: SacButtonVariant.outline,
                  fullWidth: true,
                  isEnabled: !_busy,
                  isLoading: _busyProvider == provider,
                  onPressed: () => _confirmWith(provider),
                  icon: _icon(provider, context),
                ),
                const SizedBox(height: 8),
              ],
            ],
            if (_fieldError != null) ...[
              const SizedBox(height: 8),
              Text(
                _fieldError!,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ],
          ],
        ),
        actions: [
          SacDialogAction(
            label: 'common.cancel'.tr(),
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            style: SacDialogActionStyle.cancel,
          ),
          SacDialogAction(
            label: 'profile.settings.delete_account_tile'.tr(),
            onPressed: _busy ? null : () => _submit(providers),
            style: SacDialogActionStyle.destructive,
          ),
        ],
      ),
    );
  }
}
