import 'package:flutter/material.dart';

/// Animated number counter widget — Apple Fitness / Duolingo stats style.
///
/// Counts from [begin] to [value] using a spring-like ease-out curve.
/// Rebuilds are incremental: if [value] changes after first build the counter
/// animates from its current rendered value to the new target.
///
/// Example:
/// ```dart
/// AnimatedCounter(
///   value: 12,
///   style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
/// )
/// ```
class AnimatedCounter extends StatefulWidget {
  /// Target integer value to count to.
  final int value;

  /// Value to start counting from on first mount. Defaults to 0.
  final int begin;

  /// TextStyle applied to the counter number.
  final TextStyle? style;

  /// Animation duration. Defaults to 900 ms for a satisfying count.
  final Duration duration;

  /// Curve governing the count speed. [Curves.easeOutCubic] feels organic.
  final Curve curve;

  /// Optional suffix appended after the number (e.g. '%', 'pts').
  final String suffix;

  /// Optional prefix prepended before the number (e.g. '$').
  final String prefix;

  /// Whether to animate. Set false to skip for accessibility.
  final bool animate;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.begin = 0,
    this.style,
    this.duration = const Duration(milliseconds: 900),
    this.curve = Curves.easeOutCubic,
    this.suffix = '',
    this.prefix = '',
    this.animate = true,
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late int _fromValue;

  @override
  void initState() {
    super.initState();
    _fromValue = widget.begin;

    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(
      begin: widget.begin.toDouble(),
      end: widget.value.toDouble(),
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));

    if (widget.animate) {
      // Small delay so the containing screen has finished its own entrance.
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _fromValue = _animation.value.round();
      _animation = Tween<double>(
        begin: _fromValue.toDouble(),
        end: widget.value.toDouble(),
      ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final displayed = _animation.value.round();
        return Text(
          '${widget.prefix}$displayed${widget.suffix}',
          style: widget.style,
        );
      },
    );
  }
}

/// A stat tile that combines an [AnimatedCounter] with an optional label and
/// icon — ready to drop into dashboard stat rows.
///
/// Example:
/// ```dart
/// AnimatedStatTile(
///   value: 12,
///   label: 'Completadas',
///   icon: HugeIcons.strokeRoundedMedal01,
///   color: AppColors.accent,
/// )
/// ```
class AnimatedStatTile extends StatelessWidget {
  final int value;
  final String label;
  final Color color;
  final TextStyle? valueStyle;
  final TextStyle? labelStyle;
  final String suffix;
  final bool animate;

  const AnimatedStatTile({
    super.key,
    required this.value,
    required this.label,
    required this.color,
    this.valueStyle,
    this.labelStyle,
    this.suffix = '',
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedCounter(
          value: value,
          suffix: suffix,
          animate: animate,
          style: valueStyle ??
              TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: color,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: labelStyle ??
              TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color.withValues(alpha: 0.7),
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
