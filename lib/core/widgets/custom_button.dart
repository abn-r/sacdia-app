import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';

/// Botón reutilizable y configurable para toda la aplicación
@Deprecated('Use SacButton from sac_widgets.dart. Will be removed in a future release.')
class CustomButton extends StatelessWidget {
  /// Texto que se mostrará en el botón
  final String text;
  
  /// Función que se ejecuta al presionar el botón
  final VoidCallback? onPressed;
  
  /// Indica si el botón está en estado de carga
  final bool isLoading;
  
  /// Color de fondo del botón
  final Color backgroundColor;
  
  /// Color del texto y el ícono
  final Color textColor;
  
  /// Ícono opcional que se mostrará antes del texto
  final dynamic icon;
  
  /// Tamaño del ícono
  final double iconSize;
  
  /// Tamaño del texto
  final double fontSize;
  
  /// Radio del borde redondeado
  final double borderRadius;
  
  /// Padding interno del botón
  final EdgeInsetsGeometry padding;
  
  /// Espacio entre el ícono y el texto
  final double spaceBetween;
  
  /// Indica si el botón está habilitado
  final bool isEnabled;
  
  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.backgroundColor = AppColors.primary,
    this.textColor = Colors.black,
    this.icon,
    this.iconSize = 20,
    this.fontSize = 18,
    this.borderRadius = 12,
    this.padding = const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    this.spaceBetween = 8,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool effectivelyDisabled = isLoading || !isEnabled || onPressed == null;
    
    return ElevatedButton(
      onPressed: effectivelyDisabled ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: effectivelyDisabled 
            ? backgroundColor.withValues(alpha: 0.6) 
            : backgroundColor,
        disabledBackgroundColor: context.sac.textTertiary.withValues(alpha: 0.6),
        padding: padding,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      child: isLoading
          ? SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                color: textColor,
                strokeWidth: 2.0,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  buildIcon(
                    icon,
                    color: textColor,
                    size: iconSize,
                  ),
                  SizedBox(width: spaceBetween),
                ],
                Text(
                  text,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
    );
  }
}
