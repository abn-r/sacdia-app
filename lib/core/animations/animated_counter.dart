import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';

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

  /// Curve governing the count speed. Defaults to [SacMotion.easeOut].
  final Curve curve;

  /// Optional suffix appended after the number (e.g. '%', 'pts').
  final String suffix;

  /// Optional prefix prepended before the number (e.g. '$').
  final String prefix;

  /// Whether to animate. System Reduced Motion is honored automatically.
  final bool animate;

  /// Optional formatter for the displayed number (e.g. thousand separators).
  /// When null the raw integer is shown.
  final String Function(int value)? formatter;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.begin = 0,
    this.style,
    this.duration = const Duration(milliseconds: 900),
    this.curve = SacMotion.easeOut,
    this.suffix = '',
    this.prefix = '',
    this.animate = true,
    this.formatter,
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  Timer? _delayedStart;
  bool? _reduceMotion;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(
      begin: widget.begin.toDouble(),
      end: widget.value.toDouble(),
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = SacMotion.reduceMotionOf(context);
    if (_reduceMotion == reduceMotion) return;

    final firstDependencyRead = _reduceMotion == null;
    _reduceMotion = reduceMotion;

    if (reduceMotion || !widget.animate) {
      _delayedStart?.cancel();
      _controller.stop();
      _controller.value = 1.0;
    } else if (firstDependencyRead) {
      // Let the containing screen finish its own entrance first.
      _delayedStart = Timer(SacMotion.modal, () {
        if (mounted && _reduceMotion == false) _controller.forward();
      });
    }
  }

  @override
  void didUpdateWidget(AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    if (oldWidget.value != widget.value) {
      final fromValue = _animation.value;
      _animation = Tween<double>(
        begin: fromValue,
        end: widget.value.toDouble(),
      ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));

      if (_reduceMotion == true || !widget.animate) {
        _delayedStart?.cancel();
        _controller.stop();
        _controller.value = 1.0;
      } else {
        _controller.forward(from: 0);
      }
    } else if (oldWidget.animate && !widget.animate) {
      _delayedStart?.cancel();
      _controller.stop();
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _delayedStart?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final displayed = _animation.value.round();
        final text = widget.formatter?.call(displayed) ?? '$displayed';
        return Text(
          '${widget.prefix}$text${widget.suffix}',
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
