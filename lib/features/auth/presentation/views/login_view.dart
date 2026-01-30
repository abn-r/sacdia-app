import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/widgets/custom_text_field.dart';
import 'package:sacdia_app/features/auth/presentation/views/register_view.dart';

import '../../../../core/utils/validators.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_button.dart';

/// Vista para el inicio de sesión
class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // La redirección se maneja ahora centralmente en AuthGate
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      final success = await ref.read(authNotifierProvider.notifier).signIn(
            email: email,
            password: password,
          );

      if (!success && mounted) {
        final error = ref.read(authNotifierProvider).error;
        setState(() {
          _errorMessage =
              'Credenciales incorrectas, por favor revise su correo y contraseña.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al iniciar sesión: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sacGreen,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    'assets/img/LogoSACDIA.png',
                    width: 160,
                    height: 160,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Bienvenido de nuevo',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  CustomTextField(
                    controller: _emailController,
                    hintText: 'Escribe tu correo electrónico',
                    labelText: 'CORREO',
                    keyboardType: TextInputType.emailAddress,
                    obscureText: false,
                    isPrefixHugeIcon: true,
                    prefixIcon: HugeIcons.strokeRoundedMail02,
                    validator: Validators.validateEmail,
                  ),
                  const SizedBox(height: 15),
                  CustomTextField(
                    controller: _passwordController,
                    hintText: 'Escribe tu contraseña',
                    labelText: 'CONTRASEÑA',
                    keyboardType: TextInputType.visiblePassword,
                    obscureText: true,
                    isPrefixHugeIcon: true,
                    prefixIcon: HugeIcons.strokeRoundedLockPassword,
                    validator: Validators.validatePassword,
                  ),
                  const SizedBox(height: 20),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      text: '¿Olvidaste tu contraseña?',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      children: [
                        TextSpan(
                          text: '¡Recupérala aquí!',
                          style: const TextStyle(
                              color: AppColors.sacBlack,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              //context.go('/forgot-password');
                            },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedAlert01,
                            size: 30,
                            color: Colors.red[700]!,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                  color: Colors.red[700], fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 10),
                  AuthButton(
                    text: 'Iniciar Sesión',
                    isLoading: _isLoading,
                    onPressed: _signIn,
                  ),
                  const SizedBox(height: 40),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      text: '¿Aún no tienes cuenta? ',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      children: [
                        TextSpan(
                          text: '¡Regístrate aquí!',
                          style: const TextStyle(
                              color: AppColors.sacBlack,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.push(
                                context, 
                                MaterialPageRoute(builder: (context) => const RegisterView()),
                              );
                            },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
