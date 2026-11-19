import 'package:flutter/material.dart';

import 'motion_tokens.dart';

/// Reveals [child] left to right once, like a stroke being drawn
/// ([SacMotion.draw], after an 80 ms delay). Same effect as the validated
/// check of the state panel. Reduced Motion shows the child at once.
class SacDrawReveal extends StatefulWidget {
  const SacDrawReveal({super.key, required this.child});

  final Widget child;

  @override
  State<SacDrawReveal> createState() => _SacDrawRevealState();
}

class _SacDrawRevealState extends State<SacDrawReveal>
    with SingleTickerProviderStateMixin {
  static const _delay = Duration(milliseconds: 80);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: SacMotion.draw + _delay,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (SacMotion.reduceMotionOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
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
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        if (_controller.isCompleted) return child!;
        final start =
            _delay.inMilliseconds / (SacMotion.draw + _delay).inMilliseconds;
        final t = ((_controller.value - start) / (1 - start)).clamp(0.0, 1.0);
        return ClipRect(
          clipper: _WipeClipper(SacMotion.easeOut.transform(t)),
          child: child,
        );
      },
    );
  }
}

class _WipeClipper extends CustomClipper<Rect> {
  const _WipeClipper(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(_WipeClipper oldClipper) => oldClipper.fraction != fraction;
}
