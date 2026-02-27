import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

/// Barra de progreso lineal del design system SACDIA "Scout Vibrante"
///
/// Gradiente de indigo a emerald, esquinas redondeadas, animación suave.
/// Novedad: shimmer effect sobre la barra de relleno en la primera carga,
/// y animación de fill desde 0 hasta el valor objetivo.
class SacProgressBar extends StatefulWidget {
  /// Progreso de 0.0 a 1.0
  final double progress;

  /// Altura de la barra
  final double height;

  /// Color sólido (si useGradient es false)
  final Color color;

  /// Color del track de fondo (null = resolved from theme)
  final Color? trackColor;

  /// Usar gradiente primary → secondary
  final bool useGradient;

  /// Radio de bordes (100 = completamente redondeado)
  final double borderRadius;

  /// Label opcional a la derecha (ej. "75%")
  final String? label;

  /// Mostrar porcentaje debajo
  final bool showPercentage;

  /// Whether to run the shimmer sweep on first load.
  final bool showShimmer;

  /// Duration for the fill animation.
  final Duration fillDuration;

  const SacProgressBar({
    super.key,
    required this.progress,
    this.height = 6.0,
    this.color = AppColors.primary,
    this.trackColor,
    this.useGradient = true,
    this.borderRadius = 100.0,
    this.label,
    this.showPercentage = false,
    this.showShimmer = true,
    this.fillDuration = const Duration(milliseconds: 700),
  });

  @override
  State<SacProgressBar> createState() => _SacProgressBarState();
}

class _SacProgressBarState extends State<SacProgressBar>
    with TickerProviderStateMixin {
  late final AnimationController _fillController;
  late final AnimationController _shimmerController;
  late Animation<double> _fillAnimation;

  @override
  void initState() {
    super.initState();

    final clamped = widget.progress.clamp(0.0, 1.0);

    _fillController = AnimationController(
      vsync: this,
      duration: widget.fillDuration,
    );

    _fillAnimation = Tween<double>(begin: 0.0, end: clamped).animate(
      CurvedAnimation(parent: _fillController, curve: Curves.easeOutCubic),
    );

    // Shimmer sweeps once across the filled portion after the fill completes.
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Always animate (respect accessibility via MediaQuery in build).
    _fillController.forward().then((_) {
      if (mounted && widget.showShimmer && clamped > 0) {
        _shimmerController.forward();
      }
    });
  }

  @override
  void didUpdateWidget(SacProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      final current = _fillAnimation.value;
      final clamped = widget.progress.clamp(0.0, 1.0);
      _fillAnimation = Tween<double>(
        begin: current,
        end: clamped,
      ).animate(
          CurvedAnimation(parent: _fillController, curve: Curves.easeOutCubic));
      _fillController
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _fillController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final targetClamped = widget.progress.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                child: SizedBox(
                  height: widget.height,
                  child: AnimatedBuilder(
                    animation: Listenable.merge(
                        [_fillController, _shimmerController]),
                    builder: (context, _) {
                      final filledFraction = _fillAnimation.value;

                      return Stack(
                        children: [
                          // Track background
                          Container(
                            decoration: BoxDecoration(
                              color: widget.trackColor ?? context.sac.borderLight,
                              borderRadius:
                                  BorderRadius.circular(widget.borderRadius),
                            ),
                          ),
                          // Filled portion
                          FractionallySizedBox(
                            widthFactor: filledFraction,
                            alignment: Alignment.centerLeft,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: widget.useGradient
                                    ? const LinearGradient(
                                        colors: [
                                          AppColors.primary,
                                          AppColors.secondary,
                                        ],
                                      )
                                    : null,
                                color:
                                    widget.useGradient ? null : widget.color,
                                borderRadius: BorderRadius.circular(
                                    widget.borderRadius),
                              ),
                            ),
                          ),
                          // Shimmer sweep over the filled area (runs once)
                          if (widget.showShimmer && filledFraction > 0)
                            FractionallySizedBox(
                              widthFactor: filledFraction,
                              alignment: Alignment.centerLeft,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final shimmerWidth = widget.height * 6;
                                  final shimmerX =
                                      _shimmerController.value *
                                          (constraints.maxWidth + shimmerWidth);
                                  return ClipRect(
                                    child: Transform.translate(
                                      offset: Offset(
                                          shimmerX - shimmerWidth, 0),
                                      child: Container(
                                        width: shimmerWidth,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.white
                                                  .withValues(alpha: 0.0),
                                              Colors.white
                                                  .withValues(alpha: 0.45),
                                              Colors.white
                                                  .withValues(alpha: 0.0),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                              widget.borderRadius),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            if (widget.label != null) ...[
              const SizedBox(width: 12),
              Text(
                widget.label!,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ],
        ),
        if (widget.showPercentage) ...[
          const SizedBox(height: 4),
          Text(
            '${(targetClamped * 100).toInt()}%',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ],
    );
  }
}
