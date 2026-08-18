import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/utils/validators.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/auth/presentation/widgets/auth_sky_wash.dart';
import 'package:sacdia_app/features/auth/presentation/widgets/login_club_constellation.dart';
import 'package:sacdia_app/features/auth/presentation/widgets/sac_brand_mark.dart';

/// Vista de login.
///
/// Canvas blanco (igual que el resto de la app), marca del icono SACDIA,
/// [SacTextField] sin cambios, CTA cápsula en azul del logo.
class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  static const _maxFailedAttempts = 3;
  static const _cooldownSeconds = 30;

  int _failedAttempts = 0;
  int _cooldownRemaining = 0;
  Timer? _cooldownTimer;

  bool get _isCoolingDown => _cooldownRemaining > 0;

  void _startCooldown() {
    setState(() => _cooldownRemaining = _cooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldownRemaining--;
        if (_cooldownRemaining <= 0) {
          timer.cancel();
          _failedAttempts = 0;
        }
      });
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_isCoolingDown) return;
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    await ref.read(authNotifierProvider.notifier).signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

    if (!mounted) return;
    final authState = ref.read(authNotifierProvider);
    if (authState.hasError) {
      _failedAttempts++;
      if (_failedAttempts >= _maxFailedAttempts) {
        _startCooldown();
      }
    } else {
      _failedAttempts = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;
    final errorMessage = authState.hasError
        ? (authState.error?.toString() ?? 'auth.login_error'.tr())
        : null;
    final cooldownMessage = _isCoolingDown
        ? 'auth.cooldown_message'
            .tr(namedArgs: {'seconds': '$_cooldownRemaining'})
        : null;

    final logoSize = Responsive.isLandscape(context) ? 72.0 : 108.0;
    final logoBottomSpacing = Responsive.authLogoBottomSpacing(context);
    final reduceMotion = SacMotion.reduceMotionOf(context);

    return Scaffold(
      backgroundColor: context.sac.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AuthSkyWash(),
          const LoginClubConstellation(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: Responsive.formPadding(context),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: Responsive.maxFormWidth,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 28),
                          StaggeredColumn(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            initialDelay: Duration.zero,
                            staggerDelay: SacMotion.stagger,
                            duration: SacMotion.standard,
                            slideOffset: 8,
                            animate: !reduceMotion,
                            children: [
                              Center(
                                child: SacBrandMark(size: logoSize),
                              ),
                              SizedBox(height: logoBottomSpacing),
                              Column(
                                children: [
                                  Text(
                                    'SACDIA',
                                    style: Theme.of(context)
                                        .textTheme
                                        .displayMedium
                                        ?.copyWith(
                                          letterSpacing: -0.6,
                                          height: 1.05,
                                          fontWeight: FontWeight.w700,
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  const SacBrandHairline(),
                                  const SizedBox(height: 10),
                                  Text(
                                    'auth.login_subtitle'.tr(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: context.sac.textSecondary,
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),
                              SacTextField(
                                controller: _emailController,
                                label: 'auth.email_label'.tr(),
                                hint: 'auth.email_hint'.tr(),
                                keyboardType: TextInputType.emailAddress,
                                prefixIcon: HugeIcons.strokeRoundedMail01,
                                validator: Validators.validateEmail,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 16),
                              SacTextField(
                                controller: _passwordController,
                                label: 'auth.password_label'.tr(),
                                hint: 'auth.password_hint_login'.tr(),
                                obscureText: true,
                                prefixIcon: HugeIcons.strokeRoundedLockKey,
                                validator: Validators.validatePassword,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _signIn(),
                              ),
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () =>
                                      context.push(RouteNames.forgotPassword),
                                  child: Text(
                                    'auth.forgot_password'.tr(),
                                    style: const TextStyle(
                                      color: AppColors.loginBrandBlueDark,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (errorMessage != null && !_isCoolingDown) ...[
                            SacCard(
                              backgroundColor: AppColors.errorLight,
                              borderColor:
                                  AppColors.error.withValues(alpha: 0.3),
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  HugeIcon(
                                    icon: HugeIcons.strokeRoundedAlert02,
                                    size: 20,
                                    color: AppColors.errorDark,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      errorMessage,
                                      style: const TextStyle(
                                        color: AppColors.errorDark,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (cooldownMessage != null) ...[
                            SacCard(
                              backgroundColor: AppColors.accentLight,
                              borderColor:
                                  AppColors.accent.withValues(alpha: 0.3),
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  HugeIcon(
                                    icon: HugeIcons.strokeRoundedClock01,
                                    size: 20,
                                    color: AppColors.accentDark,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      cooldownMessage,
                                      style: const TextStyle(
                                        color: AppColors.accentDark,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          SacButton(
                            text: 'auth.submit_idle'.tr(),
                            variant: SacButtonVariant.primary,
                            size: SacButtonSize.large,
                            fullWidth: true,
                            backgroundColor: AppColors.loginBrandBlue,
                            borderRadius: AppTheme.radiusFull,
                            isLoading: isLoading,
                            isEnabled: !_isCoolingDown,
                            onPressed: _signIn,
                          ),
                          const SizedBox(height: 28),
                          Center(
                            child: RichText(
                              text: TextSpan(
                                text: 'auth.no_account'.tr(),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: context.sac.textSecondary,
                                    ),
                                children: [
                                  TextSpan(
                                    text: 'auth.register_link'.tr(),
                                    style: const TextStyle(
                                      color: AppColors.loginBrandBlueDark,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () =>
                                          context.push(RouteNames.register),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
