import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/utils/validators.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';

/// Vista de login - Estilo "Scout Vibrante"
///
/// Fondo blanco, logo compacto, campos limpios, botón indigo.
/// Responsive: ConstrainedBox limita el ancho en tablets, logo se reduce
/// en landscape, padding se adapta al tamaño de pantalla.
class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authNotifierProvider.notifier).signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
    // Navigation handled by the router watching authNotifierProvider.
    // Error surfaced via ref.watch in build().
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;
    final errorMessage = authState.hasError
        ? (authState.error?.toString() ?? 'Error al iniciar sesión')
        : null;

    final logoSize = Responsive.authLogoSize(context) * 1.5;
    final logoBottomSpacing = Responsive.authLogoBottomSpacing(context);

    return Scaffold(
      backgroundColor: AppColors.sacGreen,
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
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 22),

                      // Logo — smaller in landscape to save vertical space
                      Center(
                        child: Image.asset(
                          'assets/img/LogoSACDIA.png',
                          width: logoSize,
                          height: logoSize,
                        ),
                      ),
                      SizedBox(height: logoBottomSpacing),

                      // Título
                      Text(
                        'Bienvenido de vuelta',
                        style: Theme.of(context).textTheme.displayMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Inicia sesión para continuar',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: context.sac.textSecondary,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),

                      // Campo email
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

                      // Campo password
                      SacTextField(
                        controller: _passwordController,
                        label: 'Contraseña',
                        hint: 'Tu contraseña',
                        obscureText: true,
                        prefixIcon: HugeIcons.strokeRoundedLockKey,
                        validator: Validators.validatePassword,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _signIn(),
                      ),
                      const SizedBox(height: 12),

                      // Forgot password link
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () =>
                              context.push(RouteNames.forgotPassword),
                          child: const Text(
                            '¿Olvidaste tu contraseña?',
                            style: TextStyle(
                                color: AppColors.sacBlack,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

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

                      // Botón login
                      SacButton.primary(
                        text: 'Iniciar Sesión',
                        backgroundColor: AppColors.sacGreenLight,
                        isLoading: isLoading,
                        onPressed: _signIn,
                      ),
                      const SizedBox(height: 24),

                      // Divider "o continúa con"
                      // Row(
                      //   children: [
                      //     Expanded(
                      //       child: Container(
                      //         height: 1,
                      //         color: context.sac.border,
                      //       ),
                      //     ),
                      //     Padding(
                      //       padding: const EdgeInsets.symmetric(horizontal: 16),
                      //       child: Text(
                      //         'o continúa con',
                      //         style: Theme.of(context)
                      //             .textTheme
                      //             .bodySmall
                      //             ?.copyWith(
                      //               color: AppColors.sacBlack,
                      //             ),
                      //       ),
                      //     ),
                      //     Expanded(
                      //       child: Container(
                      //         height: 1,
                      //         color: context.sac.border,
                      //       ),
                      //     ),
                      //   ],
                      // ),
                      // const SizedBox(height: 24),

                      // // Botones OAuth — estilo glassmorphism
                      // Row(
                      //   children: [
                      //     Expanded(
                      //       child: _OAuthButton(
                      //         onPressed: () {
                      //           // TODO: Google OAuth
                      //         },
                      //         iconPath: 'assets/svg/google_logo.svg',
                      //         label: 'Google',
                      //       ),
                      //     ),
                      //     const SizedBox(width: 14),
                      //     Expanded(
                      //       child: _OAuthButton(
                      //         onPressed: () {
                      //           // TODO: Apple OAuth
                      //         },
                      //         iconPath: 'assets/svg/apple_logo.svg',
                      //         label: 'Apple',
                      //       ),
                      //     ),
                      //   ],
                      // ),
                      const SizedBox(height: 40),

                      // Link a registro
                      Center(
                        child: RichText(
                          text: TextSpan(
                            text: '¿No tienes cuenta? ',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppColors.sacBlack,
                                ),
                            children: [
                              TextSpan(
                                text: 'Regístrate',
                                style: const TextStyle(
                                  color: AppColors.sacBlack,
                                  fontWeight: FontWeight.bold,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap =
                                      () => context.push(RouteNames.register),
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
