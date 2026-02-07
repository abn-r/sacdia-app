import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/utils/validators.dart';
import 'package:sacdia_app/core/widgets/custom_button.dart';
import 'package:sacdia_app/core/widgets/custom_text_field.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';

/// Vista para el registro de nuevos usuarios
class RegisterView extends ConsumerStatefulWidget {
  const RegisterView({super.key});

  @override
  ConsumerState<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends ConsumerState<RegisterView> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers privados para los campos del formulario
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _paternalController = TextEditingController();
  final TextEditingController _maternalController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isButtonEnabled = false; // Estado para controlar la habilitación del botón
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Agregar listeners a todos los controladores
    _nameController.addListener(_validateFields);
    _paternalController.addListener(_validateFields);
    _maternalController.addListener(_validateFields);
    _emailController.addListener(_validateFields);
    _passwordController.addListener(_validateFields);
    _confirmPasswordController.addListener(_validateFields);
  }

  @override
  void dispose() {
    // Remover listeners antes de disponer los controladores
    _nameController.removeListener(_validateFields);
    _paternalController.removeListener(_validateFields);
    _maternalController.removeListener(_validateFields);
    _emailController.removeListener(_validateFields);
    _passwordController.removeListener(_validateFields);
    _confirmPasswordController.removeListener(_validateFields);
    
    // Disponer los controladores
    _nameController.dispose();
    _paternalController.dispose();
    _maternalController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Método para validar que las contraseñas coincidan
  String? _validateConfirmPassword(String? value) {
    return Validators.validatePasswordMatch(
      _passwordController.text,
      value,
    );
  }
  
  // Método para verificar si todos los campos cumplen las condiciones
  void _validateFields() {
    // Verificamos si todos los campos están llenos
    final bool allFieldsFilled = 
        _nameController.text.isNotEmpty &&
        _paternalController.text.isNotEmpty &&
        _maternalController.text.isNotEmpty &&
        _emailController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty;
    
    // Verificamos si el email es válido - validación simplificada
    bool isEmailValid = true;
    if (_emailController.text.isNotEmpty) {
      // Validación básica de email con expresión regular
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      isEmailValid = emailRegex.hasMatch(_emailController.text);
    } else {
      isEmailValid = false;
    }
    
    // Verificamos si las contraseñas coinciden
    final bool doPasswordsMatch = 
        _passwordController.text.isNotEmpty && 
        _confirmPasswordController.text.isNotEmpty &&
        _passwordController.text == _confirmPasswordController.text;
    
    setState(() {
      _isButtonEnabled = allFieldsFilled && isEmailValid && doPasswordsMatch;
    });
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await ref.read(authNotifierProvider.notifier).signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: _nameController.text.trim(),
        paternalSurname: _paternalController.text.trim(),
        maternalSurname: _maternalController.text.trim(),
      );

      if (!success && mounted) {
        final error = ref.read(authNotifierProvider).error;
        setState(() {
          _errorMessage = error?.toString() ?? 'Error al registrar la cuenta. Por favor inténtalo nuevamente.';
        });
      } else if (success && mounted) {
        // Si el registro fue exitoso, regresar a la pantalla de login
        context.pop();
        // Mostrar un snackbar de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Cuenta creada exitosamente! Ya puedes iniciar sesión.', style: TextStyle(color: AppColors.sacBlack)),
            backgroundColor: Colors.white,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al registrar la cuenta: ${e.toString()}';
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.sacRed,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: const Text(
          'CREAR CUENTA',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
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
                  CustomTextField(
                    controller: _nameController,
                    hintText: 'Escribe tu nombre',
                    labelText: 'NOMBRE',
                    keyboardType: TextInputType.name,
                    isPrefixHugeIcon: false,
                    prefixIcon: HugeIcons.strokeRoundedUser,
                    validator: Validators.validateName,
                  ),
                  const SizedBox(height: 15),
                  CustomTextField(
                    controller: _paternalController,
                    hintText: 'Escribe tu apellido paterno',
                    labelText: 'APELLIDO PATERNO',
                    keyboardType: TextInputType.name,
                    isPrefixHugeIcon: false,
                    prefixIcon: HugeIcons.strokeRoundedUser,
                    validator: (value) => Validators.validateRequired(value, 'apellido paterno'),
                  ),
                  const SizedBox(height: 15),
                  CustomTextField(
                    controller: _maternalController,
                    hintText: 'Escribe tu apellido materno',
                    labelText: 'APELLIDO MATERNO',
                    keyboardType: TextInputType.name,
                    isPrefixHugeIcon: false,
                    prefixIcon: HugeIcons.strokeRoundedUser,
                    validator: (value) => Validators.validateRequired(value, 'apellido materno'),
                  ),
                  const SizedBox(height: 15),
                  CustomTextField(
                    controller: _emailController,
                    hintText: 'Escribe tu correo electrónico',
                    labelText: 'CORREO',
                    keyboardType: TextInputType.emailAddress,
                    isPrefixHugeIcon: false,
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
                    isPrefixHugeIcon: false,
                    prefixIcon: HugeIcons.strokeRoundedLockPassword,
                    validator: Validators.validatePassword,
                  ),
                  const SizedBox(height: 15),
                  CustomTextField(
                    controller: _confirmPasswordController,
                    hintText: 'Confirma tu contraseña',
                    labelText: 'CONFIRMAR CONTRASEÑA',
                    keyboardType: TextInputType.visiblePassword,
                    obscureText: true,
                    isPrefixHugeIcon: false,
                    prefixIcon: HugeIcons.strokeRoundedLockPassword,
                    validator: _validateConfirmPassword,
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
                          Icon(
                            Icons.error,
                            size: 30,
                            color: Colors.red[700]!,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: Colors.red[700], 
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  CustomButton(
                    text: 'Crear Cuenta',
                    isLoading: _isLoading,
                    isEnabled: _isButtonEnabled && !_isLoading,
                    onPressed: _isButtonEnabled ? _signUp : null,
                    backgroundColor: AppColors.sacRed,
                    textColor: Colors.white,
                    fontSize: 20,
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
