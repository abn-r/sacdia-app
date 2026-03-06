import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/utils/validators.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';

/// Vista de registro - Estilo "Scout Vibrante"
///
/// Fondo blanco, formulario limpio, indicador de fortaleza de contraseña,
/// botón indigo. Responsive: ConstrainedBox limita el ancho en tablets,
/// padding se adapta al tamaño de pantalla.
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

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authNotifierProvider.notifier).signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          name: _nameController.text.trim(),
          paternalSurname: _paternalController.text.trim(),
          maternalSurname: _maternalController.text.trim(),
        );

    if (success && mounted) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cuenta creada. Ya puedes iniciar sesión.'),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
    // Error is surfaced via ref.watch in build().
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;
    final errorMessage = authState.hasError
        ? (authState.error?.toString() ?? 'Error al registrar la cuenta')
        : null;

    // Responsive title: smaller on very small phones
    final isSmallPhone = Responsive.isSmallPhone(context);
    final titleStyle = isSmallPhone
        ? Theme.of(context).textTheme.headlineLarge
        : Theme.of(context).textTheme.displayMedium;

    return Scaffold(
      backgroundColor: context.sac.surface,
      body: SafeArea(
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

                      // Back button
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => context.pop(),
                              icon: HugeIcon(
                                icon: HugeIcons.strokeRoundedArrowLeft01,
                                color: context.sac.text,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: context.sac.background,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Crear cuenta',
                              style: titleStyle,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Name fields
                      SacTextField(
                        controller: _nameController,
                        label: 'Nombre',
                        hint: 'Tu nombre',
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
                              label: 'Apellido paterno',
                              hint: 'Paterno',
                              keyboardType: TextInputType.name,
                              validator: (v) => Validators.validateRequired(
                                  v, 'apellido paterno'),
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SacTextField(
                              controller: _maternalController,
                              label: 'Apellido materno',
                              hint: 'Materno',
                              keyboardType: TextInputType.name,
                              validator: (v) => Validators.validateRequired(
                                  v, 'apellido materno'),
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Email
                      SacTextField(
                        controller: _emailController,
                        label: 'Correo electrónico',
                        hint: 'tu@correo.com',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: HugeIcons.strokeRoundedMail01,
                        validator: Validators.validateEmail,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),

                      // Password
                      SacTextField(
                        controller: _passwordController,
                        label: 'Contraseña',
                        hint: 'Mínimo 6 caracteres',
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
                        label: 'Confirmar contraseña',
                        hint: 'Repite tu contraseña',
                        obscureText: true,
                        prefixIcon: HugeIcons.strokeRoundedLockKey,
                        validator: _validateConfirmPassword,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _isButtonEnabled ? _signUp() : null,
                      ),
                      const SizedBox(height: 24),

                      // Error message
                      if (errorMessage != null) ...[
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
                      SacButton.primary(
                        text: 'Crear Cuenta',
                        isLoading: isLoading,
                        isEnabled: _isButtonEnabled,
                        onPressed: _isButtonEnabled ? _signUp : null,
                      ),
                      const SizedBox(height: 24),

                      // Link to login
                      Center(
                        child: RichText(
                          text: TextSpan(
                            text: '¿Ya tienes cuenta? ',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: context.sac.textSecondary,
                                ),
                            children: [
                              TextSpan(
                                text: 'Inicia sesión',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
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
        return 'Muy débil';
      case 2:
        return 'Débil';
      case 3:
        return 'Buena';
      case 4:
        return 'Fuerte';
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
