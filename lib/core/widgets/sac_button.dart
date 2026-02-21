import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';

/// Variantes visuales del botón
enum SacButtonVariant {
  primary,
  secondary,
  outline,
  ghost,
  destructive,
  success
}

/// Tamaños del botón
enum SacButtonSize { small, medium, large }

/// Botón reutilizable del design system SACDIA "Scout Vibrante"
///
/// Soporta variantes, tamaños, animación de press (scale 0.96),
/// íconos (Material + HugeIcons), loading state, y overrides de estilo.
class SacButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isEnabled;
  final SacButtonVariant variant;
  final SacButtonSize size;
  final dynamic icon;
  final dynamic trailingIcon;
  final bool fullWidth;

  // Overrides opcionales de estilo (heredados de CustomButton)
  final Color? backgroundColor;
  final Color? textColor;
  final double? fontSize;
  final double? borderRadius;
  final EdgeInsetsGeometry? padding;
  final double? iconSize;
  final double spaceBetween;

  const SacButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.variant = SacButtonVariant.primary,
    this.size = SacButtonSize.medium,
    this.icon,
    this.trailingIcon,
    this.fullWidth = false,
    this.backgroundColor,
    this.textColor,
    this.fontSize,
    this.borderRadius,
    this.padding,
    this.iconSize,
    this.spaceBetween = 8,
  });

  /// Constructor rápido para botón primario full width
  const SacButton.primary({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.icon,
    this.trailingIcon,
    this.backgroundColor,
    this.textColor,
    this.fontSize,
    this.borderRadius,
    this.padding,
    this.iconSize,
    this.spaceBetween = 8,
  })  : variant = SacButtonVariant.primary,
        size = SacButtonSize.medium,
        fullWidth = true;

  /// Constructor rápido para botón outline
  const SacButton.outline({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.icon,
    this.trailingIcon,
    this.backgroundColor,
    this.textColor,
    this.fontSize,
    this.borderRadius,
    this.padding,
    this.iconSize,
    this.spaceBetween = 8,
  })  : variant = SacButtonVariant.outline,
        size = SacButtonSize.medium,
        fullWidth = true;

  /// Constructor rápido para botón ghost (texto)
  const SacButton.ghost({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.icon,
    this.trailingIcon,
    this.backgroundColor,
    this.textColor,
    this.fontSize,
    this.borderRadius,
    this.padding,
    this.iconSize,
    this.spaceBetween = 8,
  })  : variant = SacButtonVariant.ghost,
        size = SacButtonSize.medium,
        fullWidth = false;

  /// Constructor para botón destructivo (rojo)
  const SacButton.destructive({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.icon,
    this.trailingIcon,
    this.backgroundColor,
    this.textColor,
    this.fontSize,
    this.borderRadius,
    this.padding,
    this.iconSize,
    this.spaceBetween = 8,
  })  : variant = SacButtonVariant.destructive,
        size = SacButtonSize.medium,
        fullWidth = true;

  /// Constructor para botón success (emerald)
  const SacButton.success({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.icon,
    this.trailingIcon,
    this.backgroundColor,
    this.textColor,
    this.fontSize,
    this.borderRadius,
    this.padding,
    this.iconSize,
    this.spaceBetween = 8,
  })  : variant = SacButtonVariant.success,
        size = SacButtonSize.medium,
        fullWidth = true;

  @override
  State<SacButton> createState() => _SacButtonState();
}

class _SacButtonState extends State<SacButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnimation;

  bool get _effectivelyDisabled =>
      widget.isLoading || !widget.isEnabled || widget.onPressed == null;

  @override
  void initState() {
    super.initState();

    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 180),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (_effectivelyDisabled) return;
    HapticFeedback.lightImpact();
    _pressController.forward();
  }

  void _handleTapUp(TapUpDetails _) {
    _pressController.reverse();
  }

  void _handleTapCancel() {
    _pressController.reverse();
  }

  // Valores con override opcional — si el usuario pasa un valor custom, se usa ese
  EdgeInsetsGeometry get _padding {
    if (widget.padding != null) return widget.padding!;
    switch (widget.size) {
      case SacButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
      case SacButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 14);
      case SacButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 32, vertical: 18);
    }
  }

  double get _fontSize {
    if (widget.fontSize != null) return widget.fontSize!;
    switch (widget.size) {
      case SacButtonSize.small:
        return 13;
      case SacButtonSize.medium:
        return 16;
      case SacButtonSize.large:
        return 18;
    }
  }

  double get _minHeight {
    switch (widget.size) {
      case SacButtonSize.small:
        return 36;
      case SacButtonSize.medium:
        return 48;
      case SacButtonSize.large:
        return 56;
    }
  }

  double get _iconSize {
    if (widget.iconSize != null) return widget.iconSize!;
    switch (widget.size) {
      case SacButtonSize.small:
        return 16;
      case SacButtonSize.medium:
        return 20;
      case SacButtonSize.large:
        return 24;
    }
  }

  double get _borderRadius {
    return widget.borderRadius ?? AppTheme.radiusSM;
  }

  Color get _backgroundColor {
    if (widget.backgroundColor != null) return widget.backgroundColor!;
    switch (widget.variant) {
      case SacButtonVariant.primary:
        return AppColors.primary;
      case SacButtonVariant.secondary:
        return AppColors.primaryLight;
      case SacButtonVariant.outline:
      case SacButtonVariant.ghost:
        return Colors.transparent;
      case SacButtonVariant.destructive:
        return AppColors.error;
      case SacButtonVariant.success:
        return AppColors.secondary;
    }
  }

  Color get _foregroundColor {
    if (widget.textColor != null) return widget.textColor!;
    switch (widget.variant) {
      case SacButtonVariant.primary:
      case SacButtonVariant.destructive:
      case SacButtonVariant.success:
        return Colors.white;
      case SacButtonVariant.secondary:
        return AppColors.primaryDark;
      case SacButtonVariant.outline:
      case SacButtonVariant.ghost:
        return AppColors.primary;
    }
  }

  BorderSide? get _borderSide {
    if (widget.variant == SacButtonVariant.outline) {
      return const BorderSide(color: AppColors.primary, width: 1.5);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_borderRadius),
      side: _borderSide ?? BorderSide.none,
    );

    final style = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return _backgroundColor.withValues(alpha: 0.5);
        }
        return _backgroundColor;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return _foregroundColor.withValues(alpha: 0.5);
        }
        return _foregroundColor;
      }),
      overlayColor: WidgetStateProperty.all(
        _foregroundColor.withValues(alpha: 0.1),
      ),
      elevation: WidgetStateProperty.all(0),
      padding: WidgetStateProperty.all(_padding),
      minimumSize: WidgetStateProperty.all(
        Size(widget.fullWidth ? double.infinity : 0, _minHeight),
      ),
      shape: WidgetStateProperty.all(shape),
      textStyle: WidgetStateProperty.all(
        TextStyle(fontSize: _fontSize, fontWeight: FontWeight.w600),
      ),
    );

    final child = widget.isLoading
        ? SizedBox(
            height: _iconSize,
            width: _iconSize,
            child: CircularProgressIndicator(
              color: _foregroundColor,
              strokeWidth: 2.0,
            ),
          )
        : Row(
            mainAxisSize:
                widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                buildIcon(widget.icon,
                    size: _iconSize, color: _foregroundColor),
                SizedBox(width: widget.spaceBetween),
              ],
              Flexible(
                child: Text(
                  widget.text,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.trailingIcon != null) ...[
                SizedBox(width: widget.spaceBetween),
                buildIcon(widget.trailingIcon,
                    size: _iconSize, color: _foregroundColor),
              ],
            ],
          );

    Widget button;
    if (widget.variant == SacButtonVariant.ghost) {
      button = TextButton(
        onPressed: _effectivelyDisabled ? null : widget.onPressed,
        style: style,
        child: child,
      );
    } else {
      button = ElevatedButton(
        onPressed: _effectivelyDisabled ? null : widget.onPressed,
        style: style,
        child: child,
      );
    }

    // Animación de press — scale down sutil con haptic feedback
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: button,
      ),
    );
  }
}
