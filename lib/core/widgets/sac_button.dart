import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
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
/// Press: scale [SacMotion.pressScale] / [SacMotion.press] / [SacMotion.easeOut].
/// Sin splash Material. Íconos HugeIcons, loading y overrides de estilo.
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
  final Color? borderColor;
  final double? fontSize;
  final double? borderRadius;
  final EdgeInsetsGeometry? padding;
  final double? iconSize;
  final double spaceBetween;
  final int labelMaxLines;
  final TextOverflow labelOverflow;
  final String? loadingSemanticLabel;

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
    this.borderColor,
    this.fontSize,
    this.borderRadius,
    this.padding,
    this.iconSize,
    this.spaceBetween = 8,
    this.labelMaxLines = 1,
    this.labelOverflow = TextOverflow.ellipsis,
    this.loadingSemanticLabel,
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
    this.borderColor,
    this.fontSize,
    this.borderRadius,
    this.padding,
    this.iconSize,
    this.spaceBetween = 8,
    this.labelMaxLines = 1,
    this.labelOverflow = TextOverflow.ellipsis,
    this.loadingSemanticLabel,
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
    this.borderColor,
    this.fontSize,
    this.borderRadius,
    this.padding,
    this.iconSize,
    this.spaceBetween = 8,
    this.labelMaxLines = 1,
    this.labelOverflow = TextOverflow.ellipsis,
    this.loadingSemanticLabel,
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
    this.borderColor,
    this.fontSize,
    this.borderRadius,
    this.padding,
    this.iconSize,
    this.spaceBetween = 8,
    this.labelMaxLines = 1,
    this.labelOverflow = TextOverflow.ellipsis,
    this.loadingSemanticLabel,
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
    this.borderColor,
    this.fontSize,
    this.borderRadius,
    this.padding,
    this.iconSize,
    this.spaceBetween = 8,
    this.labelMaxLines = 1,
    this.labelOverflow = TextOverflow.ellipsis,
    this.loadingSemanticLabel,
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
    this.borderColor,
    this.fontSize,
    this.borderRadius,
    this.padding,
    this.iconSize,
    this.spaceBetween = 8,
    this.labelMaxLines = 1,
    this.labelOverflow = TextOverflow.ellipsis,
    this.loadingSemanticLabel,
  })  : variant = SacButtonVariant.success,
        size = SacButtonSize.medium,
        fullWidth = true;

  @override
  State<SacButton> createState() => _SacButtonState();
}

class _SacButtonState extends State<SacButton> {
  bool _pressed = false;

  bool get _effectivelyDisabled =>
      widget.isLoading || !widget.isEnabled || widget.onPressed == null;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _handlePressed() {
    if (_effectivelyDisabled) return;
    widget.onPressed?.call();
  }

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
    if (widget.borderColor != null) {
      return BorderSide(color: widget.borderColor!, width: 1.5);
    }
    if (widget.variant == SacButtonVariant.outline) {
      return const BorderSide(color: AppColors.primary, width: 1.5);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final reduce = SacMotion.reduceMotionOf(context);

    // Loading blocks interaction, but keeps the configured visual hierarchy.
    // Only genuinely disabled, non-loading buttons use disabled tokens.
    final visuallyDisabled = _effectivelyDisabled && !widget.isLoading;
    final effectiveBg = visuallyDisabled ? c.surface : _backgroundColor;
    final baseFg = visuallyDisabled ? c.textTertiary : _foregroundColor;
    final effectiveFg = widget.isLoading
        ? _accessibleLoadingForeground(baseFg, effectiveBg, c.surface)
        : baseFg;
    final effectiveBorder = visuallyDisabled
        ? BorderSide(color: c.border, width: 1.5)
        : (_borderSide ?? BorderSide.none);

    final loadingIndicator = SizedBox(
      height: _iconSize,
      width: _iconSize,
      child: CircularProgressIndicator(
        color: effectiveFg,
        strokeWidth: 2.0,
      ),
    );
    final label = Text(
      widget.text,
      maxLines: widget.labelMaxLines,
      overflow: widget.labelOverflow,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: _fontSize,
        fontWeight: FontWeight.w600,
        color: effectiveFg,
      ),
    );
    final child = widget.isLoading
        ? widget.loadingSemanticLabel == null
            ? Center(child: loadingIndicator)
            : Semantics(
                label: widget.loadingSemanticLabel,
                liveRegion: true,
                child: Center(child: loadingIndicator),
              )
        : Row(
            mainAxisSize:
                widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                buildIcon(widget.icon, size: _iconSize, color: effectiveFg),
                SizedBox(width: widget.spaceBetween),
              ],
              widget.fullWidth ? Flexible(child: label) : label,
              if (widget.trailingIcon != null) ...[
                SizedBox(width: widget.spaceBetween),
                buildIcon(widget.trailingIcon,
                    size: _iconSize, color: effectiveFg),
              ],
            ],
          );

    final visual = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: _minHeight,
        minWidth: widget.fullWidth ? double.infinity : 0,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: effectiveBg,
          borderRadius: BorderRadius.circular(_borderRadius),
          border: Border.fromBorderSide(effectiveBorder),
        ),
        child: Padding(
          padding: _padding,
          child: child,
        ),
      ),
    );

    return FocusableActionDetector(
      enabled: !_effectivelyDisabled,
      mouseCursor: _effectivelyDisabled
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _handlePressed();
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        enabled: !_effectivelyDisabled,
        label: widget.text,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _effectivelyDisabled
              ? null
              : (_) {
                  HapticFeedback.lightImpact();
                  _setPressed(true);
                },
          onTapUp: _effectivelyDisabled ? null : (_) => _setPressed(false),
          onTapCancel: _effectivelyDisabled ? null : () => _setPressed(false),
          onTap: _effectivelyDisabled ? null : _handlePressed,
          child: AnimatedScale(
            scale: (!reduce && _pressed) ? SacMotion.pressScale : 1,
            duration: SacMotion.press,
            curve: SacMotion.easeOut,
            child: visual,
          ),
        ),
      ),
    );
  }
}

Color _accessibleLoadingForeground(
  Color preferred,
  Color background,
  Color surface,
) {
  final paintedBackground = Color.alphaBlend(background, surface);
  if (_contrastRatio(preferred, paintedBackground) >= 3) return preferred;

  final candidates = <Color>[AppColors.ink900, Colors.white];
  return candidates.reduce(
    (best, candidate) => _contrastRatio(candidate, paintedBackground) >
            _contrastRatio(best, paintedBackground)
        ? candidate
        : best,
  );
}

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter =
      firstLuminance > secondLuminance ? firstLuminance : secondLuminance;
  final darker =
      firstLuminance > secondLuminance ? secondLuminance : firstLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
