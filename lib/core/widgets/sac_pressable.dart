import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';

/// Press scale on pointer-down. Same numbers as [SacButton] / [SacCard].
///
/// [listenOnly] uses a [Listener] so the child keeps its own tap arena
/// (e.g. Club address field). Do not set [onTap] in that mode.
class SacPressable extends StatefulWidget {
  const SacPressable({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
    this.listenOnly = false,
    this.semanticLabel,
    this.semanticButton = true,
  }) : assert(
          !listenOnly || onTap == null,
          'SacPressable.listenOnly cannot own onTap; the child must.',
        );

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final bool listenOnly;
  final String? semanticLabel;
  final bool semanticButton;

  @override
  State<SacPressable> createState() => _SacPressableState();
}

class _SacPressableState extends State<SacPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !widget.enabled) return;
    setState(() => _pressed = value);
  }

  @override
  void didUpdateWidget(covariant SacPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _pressed) _pressed = false;
  }

  @override
  Widget build(BuildContext context) {
    final reduce = SacMotion.reduceMotionOf(context);
    Widget child = AnimatedScale(
      scale: (!reduce && _pressed && widget.enabled) ? SacMotion.pressScale : 1,
      duration: SacMotion.press,
      curve: SacMotion.easeOut,
      child: widget.child,
    );

    if (widget.listenOnly) {
      child = Listener(
        onPointerDown: widget.enabled
            ? (_) {
                HapticFeedback.lightImpact();
                _setPressed(true);
              }
            : null,
        onPointerUp: widget.enabled ? (_) => _setPressed(false) : null,
        onPointerCancel: widget.enabled ? (_) => _setPressed(false) : null,
        child: child,
      );
    } else {
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enabled
            ? (_) {
                HapticFeedback.lightImpact();
                _setPressed(true);
              }
            : null,
        onTapUp: widget.enabled ? (_) => _setPressed(false) : null,
        onTapCancel: widget.enabled ? () => _setPressed(false) : null,
        onTap: widget.enabled ? widget.onTap : null,
        child: child,
      );
    }

    if (widget.semanticLabel == null) return child;

    return Semantics(
      button: widget.semanticButton,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      child: child,
    );
  }
}
