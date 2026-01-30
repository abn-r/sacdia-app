import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';

class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final bool obscureText;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final dynamic prefixIcon; // Puede ser IconData o HugeIcons
  final bool isPrefixHugeIcon;
  final void Function(String?)? onChanged;
  final bool isNumber;
  final int? maxLength;
  final MaxLengthEnforcement? maxLengthEnforcement;
  final List<TextInputFormatter>? inputFormatters;
  final bool autovalidateMode;
  final EdgeInsetsGeometry? margin;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.keyboardType,
    this.hintText = 'Escriba aquí...',
    this.obscureText = false,
    this.validator,
    this.prefixIcon,
    this.isPrefixHugeIcon = false,
    this.onChanged,
    this.isNumber = false,
    this.maxLength,
    this.maxLengthEnforcement,
    this.inputFormatters,
    this.autovalidateMode = false,
    this.margin = const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
  });

  @override
  CustomTextFieldState createState() => CustomTextFieldState();
}

class CustomTextFieldState extends State<CustomTextField> {
  late bool _obscureText;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
  }

  void _toggleObscureText() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }
  
  // Método para actualizar el error manualmente
  void _updateErrorMessage() {
    if (widget.validator != null) {
      setState(() {
        _errorMessage = widget.validator!(widget.controller.text);
        _hasError = _errorMessage != null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Define un radio constante para los bordes
    const double borderRadius = 12;
    
    return Container(
      margin: widget.margin,
      child: FormField<String>(
        autovalidateMode: widget.autovalidateMode 
            ? AutovalidateMode.onUserInteraction 
            : AutovalidateMode.disabled,
        validator: widget.validator != null ? (_) {
          // Actualizar el mensaje de error y el estado
          _updateErrorMessage();
          return _errorMessage;
        } : null,
        builder: (formFieldState) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(
            widget.labelText,
            style: Theme.of(context)
                .textTheme
                .titleLarge!
                .copyWith(color: AppColors.sacBlack, fontWeight: FontWeight.w600),
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  offset: const Offset(0, 4.2),
                  blurRadius: 38.4,
                ),
              ],
              borderRadius: const BorderRadius.all(Radius.circular(borderRadius)),
              border: _hasError
                  ? Border.all(color: AppColors.error, width: 1)
                  : null,
            ),
            // El clipBehavior es importante para asegurar que el TextFormField respete el recorte del borde
            clipBehavior: Clip.antiAlias,
            child: TextFormField(
              controller: widget.controller,
              obscureText: _obscureText,
              keyboardType: widget.keyboardType,
              inputFormatters: widget.inputFormatters ?? (widget.isNumber
                  ? [FilteringTextInputFormatter.digitsOnly]
                  : null),
              maxLength: widget.maxLength,
              maxLengthEnforcement: widget.maxLengthEnforcement,
              autofocus: false,
              onChanged: (value) {
                // Actualizar el error cuando cambia el texto
                _updateErrorMessage();
                // Llamar al onChanged del widget si existe
                if (widget.onChanged != null) {
                  widget.onChanged!(value);
                }
              },
              autovalidateMode: AutovalidateMode.disabled, // We handle validation with FormField
              decoration: InputDecoration(
                hintText: widget.hintText,
                // Utilizar bordes personalizados y transparentes para mantener el estilo consistente
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                  borderSide: BorderSide.none,
                ),
                // Si hay maxLength, ocultar el contador
                counterText: widget.maxLength != null ? '' : null,
                // Aumentar el padding para que el texto no quede tan pegado a los bordes
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
                hintStyle: const TextStyle(color: AppColors.sacGrey),
                fillColor: Colors.white,
                filled: true,
                prefixIcon: _buildPrefixIcon(),
                suffixIcon: widget.obscureText
                    ? IconButton(
                        icon: _obscureText
                            ? const Icon(Icons.visibility, color: AppColors.sacBlack)
                            : const Icon(Icons.visibility_off, color: AppColors.sacBlack),
                        onPressed: _toggleObscureText,
                      )
                    : null,
                // Show error styling like in AuthTextField
                // Hide the built-in error as we're showing it separately
                errorStyle: const TextStyle(height: 0, fontSize: 0),
              ),
              // No validator here as we're using the parent FormField
            ),
          ),
          // Mostrar mensajes de error debajo del contenedor
          if (_hasError)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 6),
              child: Text(
                _errorMessage ?? '',
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 14,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget? _buildPrefixIcon() {
    if (widget.prefixIcon == null) {
      return null;
    }

    if (widget.isPrefixHugeIcon) {
      return HugeIcon(
        icon: widget.prefixIcon,
        color: AppColors.sacBlack,
        size: 24,
      );
    } else {
      return Icon(widget.prefixIcon, color: AppColors.sacGrey);
    }
  }
}
