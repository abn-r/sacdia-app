import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/validators.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';

/// Vista de recuperación de contraseña - Estilo "Scout Vibrante"
///
/// Pantalla minimalista con un solo campo de correo y mensaje
/// explicativo claro.
class ForgotPasswordView extends ConsumerStatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  ConsumerState<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends ConsumerState<ForgotPasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    setState(() => _errorMessage = null);
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await ref
          .read(authRepositoryProvider)
          .resetPassword(_emailController.text.trim());

      if (!mounted) return;

      result.fold(
        (failure) {
          setState(() {
            _errorMessage = failure.message;
            _isLoading = false;
          });
        },
        (_) {
          setState(() {
            _isLoading = false;
            _emailSent = true;
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error inesperado. Intenta de nuevo.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.sac.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),

                // Back button
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => context.pop(),
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowLeft01,
                      color: context.sac.text,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: context.sac.background,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Icon
                Center(
                  child: Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedLockPassword,
                        size: 40,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  'Recuperar contraseña',
                  style: Theme.of(context).textTheme.displayMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Ingresa tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.sac.textSecondary,
                        height: 1.5,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                if (_emailSent) ...[
                  // Success state
                  SacCard(
                    backgroundColor: AppColors.secondaryLight,
                    borderColor: AppColors.secondary.withValues(alpha: 0.3),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedMailOpen01,
                          size: 48,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Enlace enviado',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondaryDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Revisa tu bandeja de entrada en ${_emailController.text.trim()}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.secondaryDark,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  SacButton.outline(
                    text: 'Volver al inicio de sesión',
                    onPressed: () => context.pop(),
                  ),
                ] else ...[
                  // Email input
                  SacTextField(
                    controller: _emailController,
                    label: 'Correo electrónico',
                    hint: 'tu@correo.com',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: HugeIcons.strokeRoundedMail01,
                    validator: Validators.validateEmail,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _handleSubmit(),
                  ),
                  const SizedBox(height: 24),

                  // Error message
                  if (_errorMessage != null) ...[
                    SacCard(
                      backgroundColor: AppColors.errorLight,
                      borderColor: AppColors.error.withValues(alpha: 0.3),
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
                              _errorMessage!,
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

                  // Submit button
                  SacButton.primary(
                    text: 'Enviar enlace',
                    isLoading: _isLoading,
                    onPressed: _handleSubmit,
                  ),
                  const SizedBox(height: 40),
                  SacButton.ghost(
                    text: 'Volver al inicio de sesión',
                    onPressed: () => context.pop(),
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
