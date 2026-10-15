import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/utils/validators.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_legal_consent.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/auth/presentation/widgets/auth_sky_wash.dart';
import 'package:sacdia_app/features/auth/presentation/widgets/sac_brand_mark.dart';
import 'package:sacdia_app/features/legal/domain/entities/legal_document.dart';
import 'package:sacdia_app/features/legal/presentation/providers/legal_providers.dart';

/// Versiones y URLs de los documentos legales vigentes, listas para enviar.
typedef _LegalSnapshot = ({
  String termsVersion,
  String privacyVersion,
  String termsUrl,
  String privacyUrl,
});

/// Extrae terms y privacy de [documents]; null si falta alguno (no se puede
/// registrar evidencia sin las dos versiones).
_LegalSnapshot? _legalSnapshot(List<LegalDocument>? documents) {
  if (documents == null) return null;
  LegalDocument? terms;
  LegalDocument? privacy;
  for (final doc in documents) {
    if (doc.documentType == LegalDocumentTypes.terms) terms = doc;
    if (doc.documentType == LegalDocumentTypes.privacy) privacy = doc;
  }
  if (terms == null || privacy == null) return null;
  return (
    termsVersion: terms.version,
    privacyVersion: privacy.version,
    termsUrl: terms.url,
    privacyUrl: privacy.url,
  );
}

/// Vista de registro.
///
/// Misma atmósfera que login (cielo azul, CTA cápsula) sin marca ni
/// logos flotantes. [SacTextField] y el acomodo del formulario no cambian.
class RegisterView extends ConsumerStatefulWidget {
  const RegisterView({super.key});

  @override
  ConsumerState<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends ConsumerState<RegisterView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _paternalController = TextEditingController();
  final _maternalController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isButtonEnabled = false;
  bool _acceptedLegal = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_validateFields);
    _paternalController.addListener(_validateFields);
    _maternalController.addListener(_validateFields);
    _emailController.addListener(_validateFields);
    _passwordController.addListener(_validateFields);
    _confirmPasswordController.addListener(_validateFields);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _paternalController.dispose();
    _maternalController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _validateFields() {
    final allFilled = _nameController.text.isNotEmpty &&
        _paternalController.text.isNotEmpty &&
        _maternalController.text.isNotEmpty &&
        _emailController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty;

    final emailValid = RegExp(r'^[\w\-.]+@([\w\-]+\.)+[\w\-]{2,4}$')
        .hasMatch(_emailController.text);

    final passwordsMatch = _passwordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty &&
        _passwordController.text == _confirmPasswordController.text;

    setState(() {
      _isButtonEnabled = allFilled && emailValid && passwordsMatch;
    });
  }

  String? _validateConfirmPassword(String? value) {
    return Validators.validatePasswordMatch(
      _passwordController.text,
      value,
    );
  }

  bool _canSubmit(_LegalSnapshot? legal) =>
      _isButtonEnabled && _acceptedLegal && legal != null;

  Future<void> _signUp() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    // Echo the versions the user actually saw (GET /legal/current), never
    // app-side constants.
    final legal = _legalSnapshot(
      ref.read(currentLegalDocumentsProvider).valueOrNull,
    );
    if (legal == null || !_acceptedLegal) return;

    final success = await ref.read(authNotifierProvider.notifier).signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          name: _nameController.text.trim(),
          paternalSurname: _paternalController.text.trim(),
          maternalSurname: _maternalController.text.trim(),
          acceptedTermsVersion: legal.termsVersion,
          acceptedPrivacyVersion: legal.privacyVersion,
        );

    if (success && mounted) {
      context.pop();
      SacSnackBar.show(context, 'auth.register_success'.tr(),
          backgroundColor: AppColors.secondary);
      return;
    }
    // On any failure re-fetch the current documents: a LEGAL_VERSION_MISMATCH
    // means they changed while the form was open. The ref.listen in build()
    // clears the checkbox when the versions differ.
    ref.invalidate(currentLegalDocumentsProvider);
    // Error is surfaced via ref.watch in build().
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    // Reset the consent when the backend publishes different versions than
    // the ones the user checked.
    ref.listen<AsyncValue<List<LegalDocument>>>(currentLegalDocumentsProvider,
        (previous, next) {
      final before = _legalSnapshot(previous?.valueOrNull);
      final after = _legalSnapshot(next.valueOrNull);
      if (_acceptedLegal &&
          before != null &&
          after != null &&
          (before.termsVersion != after.termsVersion ||
              before.privacyVersion != after.privacyVersion)) {
        setState(() => _acceptedLegal = false);
      }
    });
    final legalAsync = ref.watch(currentLegalDocumentsProvider);
    final legal = _legalSnapshot(legalAsync.valueOrNull);
    final legalLoadFailed = legal == null && !legalAsync.isLoading;

    final errorMessage = authState.hasError
        ? (authState.error?.toString() ?? 'auth.register_error'.tr())
        : null;

    // Responsive title: smaller on very small phones
    final isSmallPhone = Responsive.isSmallPhone(context);
    final titleStyle = isSmallPhone
        ? Theme.of(context).textTheme.headlineLarge
        : Theme.of(context).textTheme.displayMedium;

    return Scaffold(
      backgroundColor: context.sac.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AuthSkyWash(),
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
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                SacPressable(
                                  listenOnly: true,
                                  child: IconButton(
                                    enableFeedback: false,
                                    onPressed: () => context.pop(),
                                    icon: HugeIcon(
                                      icon: HugeIcons.strokeRoundedArrowLeft01,
                                      color: context.sac.text,
                                    ),
                                    style: IconButton.styleFrom(
                                      backgroundColor: context.sac.surface
                                          .withValues(alpha: 0.86),
                                      minimumSize: const Size(44, 44),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    'auth.register_title'.tr(),
                                    style: titleStyle?.copyWith(
                                      letterSpacing: -0.6,
                                      height: 1.05,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          const SacBrandHairline(),
                          const SizedBox(height: 24),

                          // Name fields
                          SacTextField(
                            controller: _nameController,
                            label: 'auth.name_label'.tr(),
                            hint: 'auth.name_hint'.tr(),
                            keyboardType: TextInputType.name,
                            prefixIcon: HugeIcons.strokeRoundedUser,
                            validator: Validators.validateName,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 16),

                          // Surnames in a row
                          Row(
                            children: [
                              Expanded(
                                child: SacTextField(
                                  controller: _paternalController,
                                  label: 'auth.paternal_surname_label'.tr(),
                                  hint: 'auth.paternal_surname_hint'.tr(),
                                  keyboardType: TextInputType.name,
                                  validator: (v) => Validators.validateRequired(
                                      v,
                                      'auth.paternal_surname_field_name'.tr()),
                                  textInputAction: TextInputAction.next,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SacTextField(
                                  controller: _maternalController,
                                  label: 'auth.maternal_surname_label'.tr(),
                                  hint: 'auth.maternal_surname_hint'.tr(),
                                  keyboardType: TextInputType.name,
                                  validator: (v) => Validators.validateRequired(
                                      v,
                                      'auth.maternal_surname_field_name'.tr()),
                                  textInputAction: TextInputAction.next,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Email
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

                          // Password
                          SacTextField(
                            controller: _passwordController,
                            label: 'auth.password_label'.tr(),
                            hint: 'auth.password_hint'.tr(),
                            obscureText: true,
                            prefixIcon: HugeIcons.strokeRoundedLockKey,
                            validator: Validators.validatePassword,
                            textInputAction: TextInputAction.next,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 8),

                          // Password strength indicator
                          _PasswordStrengthIndicator(
                            password: _passwordController.text,
                          ),
                          const SizedBox(height: 16),

                          // Confirm password
                          SacTextField(
                            controller: _confirmPasswordController,
                            label: 'auth.confirm_password_label'.tr(),
                            hint: 'auth.confirm_password_hint'.tr(),
                            obscureText: true,
                            prefixIcon: HugeIcons.strokeRoundedLockKey,
                            validator: _validateConfirmPassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) =>
                                _canSubmit(legal) ? _signUp() : null,
                          ),
                          const SizedBox(height: 16),

                          // Legal consent (evidence of acceptance)
                          if (legal != null)
                            SacLegalConsentCheckbox(
                              value: _acceptedLegal,
                              enabled: !isLoading,
                              termsUrl: legal.termsUrl,
                              privacyUrl: legal.privacyUrl,
                              onChanged: (value) =>
                                  setState(() => _acceptedLegal = value),
                            )
                          else if (legalLoadFailed)
                            _LegalLoadError(
                              onRetry: () =>
                                  ref.invalidate(currentLegalDocumentsProvider),
                            )
                          else
                            const SizedBox(height: 48),
                          const SizedBox(height: 24),

                          // Error message
                          if (errorMessage != null) ...[
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

                          // Register button
                          SacButton(
                            text: 'auth.register_button'.tr(),
                            variant: SacButtonVariant.primary,
                            size: SacButtonSize.large,
                            fullWidth: true,
                            backgroundColor: AppColors.loginBrandBlue,
                            borderRadius: AppTheme.radiusFull,
                            isLoading: isLoading,
                            isEnabled: _canSubmit(legal),
                            onPressed: _canSubmit(legal) ? _signUp : null,
                          ),
                          const SizedBox(height: 24),

                          Center(
                            child: RichText(
                              text: TextSpan(
                                text: 'auth.have_account'.tr(),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: context.sac.textSecondary,
                                    ),
                                children: [
                                  TextSpan(
                                    text: 'auth.login_link'.tr(),
                                    style: const TextStyle(
                                      color: AppColors.loginBrandBlueDark,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () => context.pop(),
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

/// Error al cargar los documentos legales vigentes, con reintento. Mientras
/// dure, el registro queda deshabilitado.
class _LegalLoadError extends StatelessWidget {
  final VoidCallback onRetry;

  const _LegalLoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const HugeIcon(
          icon: HugeIcons.strokeRoundedAlert02,
          size: 20,
          color: AppColors.errorDark,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'auth.legal.load_error'.tr(),
            style: const TextStyle(color: AppColors.errorDark, fontSize: 14),
          ),
        ),
        SacButton.ghost(
          text: 'auth.legal.retry'.tr(),
          textColor: AppColors.loginBrandBlueDark,
          onPressed: onRetry,
        ),
      ],
    );
  }
}

/// Indicador de fortaleza de contraseña con 4 segmentos.
///
/// Criterios: longitud >= 6, mayúsculas, números, caracteres especiales.
/// Colores: rojo (débil) → ámbar (media) → esmeralda (fuerte).
class _PasswordStrengthIndicator extends StatelessWidget {
  final String password;

  const _PasswordStrengthIndicator({required this.password});

  int get _strength {
    if (password.isEmpty) return 0;
    int score = 0;
    if (password.length >= 6) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) score++;
    return score;
  }

  String get _label {
    switch (_strength) {
      case 0:
        return '';
      case 1:
        return 'auth.password_strength_very_weak'.tr();
      case 2:
        return 'auth.password_strength_weak'.tr();
      case 3:
        return 'auth.password_strength_good'.tr();
      case 4:
        return 'auth.password_strength_strong'.tr();
      default:
        return '';
    }
  }

  Color _segmentColor(int index, BuildContext context) {
    if (index >= _strength) return context.sac.borderLight;
    switch (_strength) {
      case 1:
        return AppColors.error;
      case 2:
        return AppColors.accent;
      case 3:
        return AppColors.accent;
      case 4:
        return AppColors.secondary;
      default:
        return context.sac.borderLight;
    }
  }

  Color _labelColor(BuildContext context) {
    switch (_strength) {
      case 1:
        return AppColors.error;
      case 2:
        return AppColors.accent;
      case 3:
        return AppColors.accent;
      case 4:
        return AppColors.secondary;
      default:
        return context.sac.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (index) {
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 4,
                margin: EdgeInsets.only(right: index < 3 ? 4 : 0),
                decoration: BoxDecoration(
                  color: _segmentColor(index, context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(
          _label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _labelColor(context),
          ),
        ),
      ],
    );
  }
}
