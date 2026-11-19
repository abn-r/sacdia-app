import 'package:flutter/material.dart';

import 'motion_tokens.dart';

/// A number that rolls when it changes: the old one leaves upward and the new
/// one enters from below (the other way round when the value goes down),
/// [SacMotion.switcher] long, with a fade.
///
/// At rest it is one plain [Text] of `prefix + value + suffix`, so the label
/// reads (and tests find it) as a single string. Only while the value changes
/// does it split into prefix, rolling number and suffix. The first build never
/// animates. Reduced Motion keeps a short cross-fade and drops the movement.
///
/// ```dart
/// SacRollingNumber(value: 3, prefix: 'Enviar ', suffix: ' archivos')
/// ```
class SacRollingNumber extends StatefulWidget {
  const SacRollingNumber({
    super.key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.style,
    this.textKey,
    this.textAlign,
  });

  final int value;

  /// Text before the number; it does not move.
  final String prefix;

  /// Text after the number; it does not move.
  final String suffix;

  /// Falls back to the ambient [DefaultTextStyle].
  final TextStyle? style;

  /// Key of the resting [Text].
  final Key? textKey;

  final TextAlign? textAlign;

  /// How far, as a fraction of the line height, a number travels.
  static const double travel = 0.7;

  @override
  State<SacRollingNumber> createState() => _SacRollingNumberState();
}

class _SacRollingNumberState extends State<SacRollingNumber>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _rolling = false;
  int _from = 0;
  int _direction = 1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _rolling = false);
        }
      });
  }

  @override
  void didUpdateWidget(SacRollingNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) return;
    _from = oldWidget.value;
    _direction = widget.value > oldWidget.value ? 1 : -1;
    _rolling = true;
    _controller.duration = SacMotion.reduceMotionOf(context)
        ? SacMotion.reducedFade
        : SacMotion.switcher;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Text _text(String data, {Key? key}) => Text(
        data,
        key: key,
        style: widget.style,
        textAlign: widget.textAlign,
      );

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final label = '${w.prefix}${w.value}${w.suffix}';
    if (!_rolling) return _text(label, key: w.textKey);

    final reduce = SacMotion.reduceMotionOf(context);
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = SacMotion.easeOut.transform(_controller.value);
          final travel = reduce ? 0.0 : SacRollingNumber.travel;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (w.prefix.isNotEmpty) _text(w.prefix),
              ClipRect(
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    FractionalTranslation(
                      translation: Offset(0, -_direction * travel * t),
                      child: Opacity(
                        opacity: 1 - t,
                        child: _text('$_from'),
                      ),
                    ),
                    FractionalTranslation(
                      translation: Offset(0, _direction * travel * (1 - t)),
                      child: Opacity(opacity: t, child: _text('${w.value}')),
                    ),
                  ],
                ),
              ),
              if (w.suffix.isNotEmpty) _text(w.suffix),
            ],
          );
        },
      ),
    );
  }
}
