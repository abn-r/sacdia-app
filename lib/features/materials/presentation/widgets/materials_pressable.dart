import 'package:flutter/material.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';

/// Press feedback: scale on touch-down (Apple response + Emil craft).
class MaterialsPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  const MaterialsPressable({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.97,
  });

  @override
  State<MaterialsPressable> createState() => _MaterialsPressableState();
}

class _MaterialsPressableState extends State<MaterialsPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || widget.onTap == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = SacMotion.reduceMotionOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: (!reduce && _pressed) ? widget.pressedScale : 1,
        duration: SacMotion.press,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
