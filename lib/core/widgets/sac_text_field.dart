import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

class SacTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helperText;
  final bool obscureText;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final dynamic prefixIcon;
  final Widget? suffix;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final bool enabled;
  final bool readOnly;
  final int? maxLength;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final AutovalidateMode autovalidateMode;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final TextCapitalization textCapitalization;

  const SacTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.obscureText = false,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.readOnly = false,
    this.maxLength,
    this.maxLines = 1,
    this.inputFormatters,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.focusNode,
    this.textInputAction,
    this.onTap,
    this.margin,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  State<SacTextField> createState() => _SacTextFieldState();
}

class _SacTextFieldState extends State<SacTextField> {
  late bool _obscureText;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
  }

  /// Actualiza el estado de error manualmente
  void _updateError() {
    if (widget.validator != null) {
      setState(() {
        _errorMessage = widget.validator!(widget.controller?.text ?? '');
        _hasError = _errorMessage != null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: widget.margin,
      child: FormField<String>(
        autovalidateMode: widget.autovalidateMode,
        validator: widget.validator != null
            ? (_) {
                _updateError();
                return _errorMessage;
              }
            : null,
        builder: (formFieldState) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label externo arriba del campo
            if (widget.label != null) ...[
              Text(
                widget.label!,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
            ],

            // Contenedor con sombra y borde de error condicional
            Container(
              decoration: BoxDecoration(
                color: widget.enabled
                    ? context.sac.surface
                    : context.sac.surfaceVariant,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    offset: const Offset(0, 3),
                    blurRadius: 20,
                  ),
                ],
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                border: _hasError
                    ? Border.all(color: theme.colorScheme.error, width: 1.5)
                    : null,
              ),
              clipBehavior: Clip.antiAlias,
              child: TextFormField(
                controller: widget.controller,
                obscureText: _obscureText,
                keyboardType: widget.keyboardType,
                onFieldSubmitted: widget.onSubmitted,
                enabled: widget.enabled,
                readOnly: widget.readOnly,
                maxLength: widget.maxLength,
                maxLines: widget.maxLines,
                inputFormatters: widget.inputFormatters,
                focusNode: widget.focusNode,
                textInputAction: widget.textInputAction,
                textCapitalization: widget.textCapitalization,
                onTap: widget.onTap,
                style: theme.textTheme.bodyMedium,
                autovalidateMode: AutovalidateMode.disabled,
                onChanged: (value) {
                  _updateError();
                  widget.onChanged?.call(value);
                },
                decoration: InputDecoration(
                  hintText: widget.hint,
                  helperText: widget.helperText,
                  counterText: widget.maxLength != null ? '' : null,
                  // Bordes transparentes — el contenedor padre maneja el estilo visual
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  hintStyle: TextStyle(color: context.sac.textTertiary),
                  filled: true,
                  fillColor: widget.enabled
                      ? context.sac.surface
                      : context.sac.surfaceVariant,
                  prefixIcon: _buildPrefixIcon(),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 0,
                  ),
                  suffixIcon: _buildSuffixIcon(),
                  // Ocultar error interno — se muestra debajo del contenedor
                  errorStyle: const TextStyle(height: 0, fontSize: 0),
                ),
              ),
            ),

            // Mensaje de error debajo del contenedor
            if (_hasError && _errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 6),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Construye el ícono de prefijo
  Widget? _buildPrefixIcon() {
    if (widget.prefixIcon == null) return null;

    return Padding(
      padding: const EdgeInsets.only(left: 15, right: 8),
      child: widget.prefixIcon is IconData
          ? Icon(widget.prefixIcon,
              size: 20, color: context.sac.textSecondary)
          : HugeIcon(
              icon: widget.prefixIcon,
              size: 20,
              color: context.sac.textSecondary),
    );
  }

  /// Construye el ícono de sufijo (toggle de contraseña o custom)
  Widget? _buildSuffixIcon() {
    if (widget.suffix != null) return widget.suffix;

    if (widget.obscureText) {
      return IconButton(
        icon: HugeIcon(
          icon: _obscureText
              ? HugeIcons.strokeRoundedViewOffSlash
              : HugeIcons.strokeRoundedViewOff,
          size: 20,
          color: context.sac.textSecondary,
        ),
        onPressed: () => setState(() => _obscureText = !_obscureText),
      );
    }

    return null;
  }
}
