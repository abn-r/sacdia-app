import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/sac_back_button.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_notice.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../../core/widgets/sac_text_field.dart';
import '../../../auth/presentation/providers/login_notice_provider.dart';
import '../providers/majority_release_providers.dart';

/// «Reclama tu cuenta» (Fase 4): una persona liberada al cumplir la mayoría de
/// edad que NO tiene credenciales canjea el código de acceso que le dio su ex
/// tutor o un director del club y crea su correo y contraseña.
///
/// Es PÚBLICA (la persona aún no tiene sesión). El canje no devuelve tokens: al
/// terminar lleva al login con el correo ya escrito; ya con sesión, el flujo
/// `/release` pide aceptar los términos. Los errores se leen por `code`; un
/// código inválido, vencido o usado se ve igual (no se revela cuál).
class AdultClaimView extends ConsumerStatefulWidget {
  const AdultClaimView({super.key});

  @override
  ConsumerState<AdultClaimView> createState() => _AdultClaimViewState();
}

class _AdultClaimViewState extends ConsumerState<AdultClaimView> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validateCode(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'adult_claim.code_required'.tr();
    return null;
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _emailController.text.trim().toLowerCase();
    final ok = await ref.read(adultClaimControllerProvider.notifier).redeem(
          code: _codeController.text.trim().toUpperCase(),
          email: email,
          password: _passwordController.text,
        );
    if (!ok || !mounted) return;
    // El correo queda escrito en el login; la contraseña nunca se guarda.
    ref.read(lastLoginIdentifierProvider.notifier).state = email;
    SacSnackBar.show(context, 'adult_claim.success'.tr(), isSuccess: true);
    context.go(RouteNames.login);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    final state = ref.watch(adultClaimControllerProvider);
    final busy = state.submitting;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: Responsive.formPadding(context),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: Responsive.maxFormWidth),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SacBackButton(
                        onPressed: busy ? null : () => _back(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'adult_claim.title'.tr(),
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'adult_claim.body'.tr(),
                      style: textTheme.bodyLarge
                          ?.copyWith(color: c.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    SacTextField(
                      key: const ValueKey('adult_claim_code'),
                      controller: _codeController,
                      label: 'adult_claim.code_label'.tr(),
                      helperText: 'adult_claim.code_help'.tr(),
                      helperMaxLines: 3,
                      autocorrect: false,
                      enabled: !busy,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r'\s')),
                      ],
                      validator: _validateCode,
                    ),
                    const SizedBox(height: 16),
                    SacTextField(
                      key: const ValueKey('adult_claim_email'),
                      controller: _emailController,
                      label: 'adult_claim.email_label'.tr(),
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      enabled: !busy,
                      textInputAction: TextInputAction.next,
                      validator: (v) => Validators.validateEmail(v?.trim()),
                    ),
                    const SizedBox(height: 16),
                    SacTextField(
                      key: const ValueKey('adult_claim_password'),
                      controller: _passwordController,
                      label: 'adult_claim.password_label'.tr(),
                      helperText: 'adult_claim.password_help'.tr(),
                      helperMaxLines: 3,
                      obscureText: true,
                      enabled: !busy,
                      textInputAction: TextInputAction.next,
                      validator: Validators.validatePassword,
                    ),
                    const SizedBox(height: 16),
                    SacTextField(
                      key: const ValueKey('adult_claim_confirm'),
                      controller: _confirmController,
                      label: 'adult_claim.confirm_label'.tr(),
                      obscureText: true,
                      enabled: !busy,
                      textInputAction: TextInputAction.done,
                      validator: (v) => Validators.validatePasswordMatch(
                        _passwordController.text,
                        v,
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                    if (state.error != null) ...[
                      const SizedBox(height: 16),
                      SacNotice(
                        key: const ValueKey('adult_claim_error'),
                        text: state.error!,
                        tone: SacNoticeTone.error,
                        liveRegion: true,
                      ),
                    ],
                    const SizedBox(height: 24),
                    SacButton(
                      key: const ValueKey('adult_claim_submit'),
                      text: 'adult_claim.submit'.tr(),
                      variant: SacButtonVariant.primary,
                      size: SacButtonSize.large,
                      fullWidth: true,
                      borderRadius: AppTheme.radiusFull,
                      isLoading: busy,
                      isEnabled: !busy,
                      onPressed: _submit,
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

  /// Se llega con `push` desde el login; si no hay a dónde volver (enlace
  /// directo), se va al login.
  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RouteNames.login);
    }
  }
}
