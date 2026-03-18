import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

/// Card del design system SACDIA "Scout Vibrante"
///
/// Fondo blanco, borde sutil, sombra muy ligera, radius 16px.
/// Opcional: barra de acento lateral (4px) estilo Google Classroom.
///
/// Novedad: [animate] activa un fade + scale entrance al montar la card.
/// [animationDelay] permite escalonar varias cards con stagger manual.
class SacCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? borderColor;
  final Color? accentColor;
  final Color? backgroundColor;

  /// Activates a subtle fade + scale-up entrance animation on mount.
  final bool animate;

  /// Optional delay before the entrance animation fires.
  /// Use this to create a manual stagger when wrapping multiple cards.
  final Duration animationDelay;

  const SacCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.borderColor,
    this.accentColor,
    this.backgroundColor,
    this.animate = false,
    this.animationDelay = Duration.zero,
  });

  @override
  State<SacCard> createState() => _SacCardState();
}

class _SacCardState extends State<SacCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _scale = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    final shouldAnimate = widget.animate;

    if (shouldAnimate) {
      Future.delayed(widget.animationDelay, () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final defaultBorder = c.border;
    final defaultBg = widget.backgroundColor ?? c.surface;
    final radius = BorderRadius.circular(AppTheme.radiusMD);

    Widget content = Container(
      margin: widget.margin,
      decoration: BoxDecoration(
        color: defaultBg,
        borderRadius: radius,
        border: Border.all(color: widget.borderColor ?? defaultBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: c.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: widget.accentColor != null
            ? IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 4, color: widget.accentColor),
                    Expanded(
                      child:
                          Padding(padding: widget.padding, child: widget.child),
                    ),
                  ],
                ),
              )
            : Padding(padding: widget.padding, child: widget.child),
      ),
    );

    if (widget.onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: radius,
          child: content,
        ),
      );
    }

    if (!widget.animate) return content;

    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: content,
      ),
    );
  }
}
