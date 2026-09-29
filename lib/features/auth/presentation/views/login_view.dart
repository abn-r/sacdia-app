import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
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
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  static const _maxFailedAttempts = 3;
  static const _cooldownSeconds = 30;

  int _failedAttempts = 0;
  int _cooldownRemaining = 0;
  Timer? _cooldownTimer;

  bool get _isCoolingDown => _cooldownRemaining > 0;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(_onFieldFocusChanged);
    _passwordFocus.addListener(_onFieldFocusChanged);
  }

  void _onFieldFocusChanged() {
    if (mounted) setState(() {});
  }

  void _hideKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _dismissKeyboardOnOutsideTap(PointerDownEvent _) {
    _hideKeyboard();
  }

  void _focusPassword() {
    _passwordFocus.requestFocus();
  }

  void _submitFromKeyboard() {
    _hideKeyboard();
    _signIn();
  }

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
    _emailFocus.removeListener(_onFieldFocusChanged);
    _passwordFocus.removeListener(_onFieldFocusChanged);
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_isCoolingDown || ref.read(authNotifierProvider).isLoading) return;
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

    final logoSize = (Responsive.isLandscape(context) ? 72.0 : 108.0) * 1.2;
    final logoBottomSpacing = Responsive.authLogoBottomSpacing(context);
    final reduceMotion = SacMotion.reduceMotionOf(context);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: context.sac.background,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const AuthSkyWash(),
                        const Positioned.fill(
                          child: LoginClubConstellation(),
                        ),
                        SafeArea(
                          child: Padding(
                            padding: Responsive.formPadding(context),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: Responsive.maxFormWidth,
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const SizedBox(height: 28),
                                    StaggeredColumn(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
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
                                                    color: context
                                                        .sac.textSecondary,
                                                  ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 32),
                                        SacTextField(
                                          controller: _emailController,
                                          focusNode: _emailFocus,
                                          label: 'auth.email_label'.tr(),
                                          hint: 'auth.email_hint'.tr(),
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          prefixIcon:
                                              HugeIcons.strokeRoundedMail01,
                                          validator: Validators.validateEmail,
                                          textInputAction: TextInputAction.next,
                                          onEditingComplete: _focusPassword,
                                          onTapOutside:
                                              _dismissKeyboardOnOutsideTap,
                                        ),
                                        const SizedBox(height: 16),
                                        SacTextField(
                                          controller: _passwordController,
                                          focusNode: _passwordFocus,
                                          label: 'auth.password_label'.tr(),
                                          hint: 'auth.password_hint_login'.tr(),
                                          obscureText: true,
                                          prefixIcon:
                                              HugeIcons.strokeRoundedLockKey,
                                          validator:
                                              Validators.validatePassword,
                                          textInputAction: TextInputAction.send,
                                          onEditingComplete: _hideKeyboard,
                                          onSubmitted: (_) => _signIn(),
                                          onTapOutside:
                                              _dismissKeyboardOnOutsideTap,
                                        ),
                                        const SizedBox(height: 4),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: SacPressable(
                                            listenOnly: true,
                                            child: TextButton(
                                              style: const ButtonStyle(
                                                  enableFeedback: false),
                                              onPressed: () => context.push(
                                                  RouteNames.forgotPassword),
                                              child: Text(
                                                'auth.forgot_password'.tr(),
                                                style: const TextStyle(
                                                  color: AppColors
                                                      .loginBrandBlueDark,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    if (errorMessage != null &&
                                        !_isCoolingDown) ...[
                                      SacCard(
                                        backgroundColor: AppColors.errorLight,
                                        borderColor: AppColors.error
                                            .withValues(alpha: 0.3),
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            HugeIcon(
                                              icon: HugeIcons
                                                  .strokeRoundedAlert02,
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
                                        borderColor: AppColors.accent
                                            .withValues(alpha: 0.3),
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            HugeIcon(
                                              icon: HugeIcons
                                                  .strokeRoundedClock01,
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
                                                color:
                                                    context.sac.textSecondary,
                                              ),
                                          children: [
                                            TextSpan(
                                              text: 'auth.register_link'.tr(),
                                              style: const TextStyle(
                                                color: AppColors
                                                    .loginBrandBlueDark,
                                                fontWeight: FontWeight.w700,
                                              ),
                                              recognizer: TapGestureRecognizer()
                                                ..onTap = () => context
                                                    .push(RouteNames.register),
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
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (keyboardOpen)
            TextFieldTapRegion(
              child: _LoginKeyboardBar(
                canGoNext: _emailFocus.hasFocus,
                canSubmit: !_isCoolingDown && !isLoading,
                onNext: _focusPassword,
                onSubmit: _submitFromKeyboard,
                onHide: _hideKeyboard,
              ),
            ),
        ],
      ),
    );
  }
}

class _LoginKeyboardBar extends StatelessWidget {
  const _LoginKeyboardBar({
    required this.canGoNext,
    required this.canSubmit,
    required this.onNext,
    required this.onSubmit,
    required this.onHide,
  });

  final bool canGoNext;
  final bool canSubmit;
  final VoidCallback onNext;
  final VoidCallback onSubmit;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.sac.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.sac.border)),
        ),
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              _LoginKeyboardAction(
                icon: HugeIcons.strokeRoundedArrowDown01,
                label: 'common.next'.tr(),
                enabled: canGoNext,
                onTap: onNext,
              ),
              _LoginKeyboardAction(
                icon: HugeIcons.strokeRoundedSent,
                label: 'auth.keyboard_send'.tr(),
                enabled: canSubmit,
                onTap: onSubmit,
              ),
              const Spacer(),
              _LoginKeyboardAction(
                icon: HugeIcons.strokeRoundedKeyboard,
                label: 'auth.keyboard_hide'.tr(),
                enabled: true,
                onTap: onHide,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginKeyboardAction extends StatelessWidget {
  const _LoginKeyboardAction({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final HugeIconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.loginBrandBlue : context.sac.textTertiary;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: ExcludeSemantics(
        child: SacPressable(
          enabled: enabled,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              height: 48,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(icon: icon, size: 18, color: color),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
