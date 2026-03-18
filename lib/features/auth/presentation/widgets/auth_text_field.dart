import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

/// Widget reutilizable para campos de texto en vistas de autenticación
class AuthTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final dynamic icon;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.icon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _showPassword = false;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: HugeIcon(
          icon: widget.icon,
          color: context.sac.textTertiary,
          size: 24,
        ),
        suffixIcon: widget.obscureText
            ? IconButton(
                icon: HugeIcon(
                  icon: _showPassword
                      ? HugeIcons.strokeRoundedViewOff
                      : HugeIcons.strokeRoundedViewOffSlash,
                  color: context.sac.textTertiary,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _showPassword = !_showPassword;
                  });
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
      keyboardType: widget.keyboardType,
      obscureText: widget.obscureText && !_showPassword,
      validator: widget.validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }
}
