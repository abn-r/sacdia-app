import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

class SacDropdownField<T> extends StatefulWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? Function(T?)? validator;
  final void Function(T?)? onChanged;
  final bool enabled;
  final dynamic prefixIcon;
  final EdgeInsetsGeometry? margin;
  final AutovalidateMode autovalidateMode;

  const SacDropdownField({
    super.key,
    required this.items,
    this.value,
    this.label,
    this.hint,
    this.helperText,
    this.validator,
    this.onChanged,
    this.enabled = true,
    this.prefixIcon,
    this.margin,
    this.autovalidateMode = AutovalidateMode.disabled,
  });

  @override
  State<SacDropdownField<T>> createState() => _SacDropdownFieldState<T>();
}

class _SacDropdownFieldState<T> extends State<SacDropdownField<T>> {
  bool _hasError = false;
  String? _errorMessage;

  void _updateError(T? value) {
    if (widget.validator != null) {
      setState(() {
        _errorMessage = widget.validator!(value);
        _hasError = _errorMessage != null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: widget.margin,
      child: Column(
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
              color:
                  widget.enabled ? context.sac.surface : context.sac.surfaceVariant,
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
            child: DropdownButtonFormField<T>(
              // Solo pasar el value si existe exactamente un item con ese valor
              value: widget.value != null &&
                      widget.items
                              .where((item) => item.value == widget.value)
                              .length ==
                          1
                  ? widget.value
                  : null,
              items: widget.items,
              onChanged: widget.enabled
                  ? (value) {
                      _updateError(value);
                      widget.onChanged?.call(value);
                    }
                  : null,
              validator: widget.validator != null
                  ? (value) {
                      _updateError(value);
                      return _errorMessage;
                    }
                  : null,
              autovalidateMode: widget.autovalidateMode,
              style: theme.textTheme.bodyMedium,
              icon: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: context.sac.textSecondary,
                  size: 22,
                ),
              ),
              isExpanded: true,
              dropdownColor: context.sac.surface,
              decoration: InputDecoration(
                hintText: widget.hint,
                helperText: widget.helperText,
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
}
