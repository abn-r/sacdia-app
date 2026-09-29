import 'package:flutter/gestures.dart';
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
    this.onLongPress,
    this.enabled = true,
    this.listenOnly = false,
    this.semanticLabel,
    this.semanticButton = true,
  }) : assert(
          !listenOnly || (onTap == null && onLongPress == null),
          'SacPressable.listenOnly cannot own onTap; the child must.',
        );

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final bool listenOnly;
  final String? semanticLabel;
  final bool semanticButton;

  @override
  State<SacPressable> createState() => _SacPressableState();
}

class _SacPressableState extends State<SacPressable> {
  bool _pressed = false;
  Offset? _pointerDown;

  void _setPressed(bool value) {
    if (_pressed == value || !widget.enabled) return;
    setState(() => _pressed = value);
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerDown = event.position;
    HapticFeedback.lightImpact();
    _setPressed(true);
  }

  void _onPointerMove(PointerMoveEvent event) {
    final origin = _pointerDown;
    if (origin == null || !_pressed) return;
    if ((event.position - origin).distance > kTouchSlop) {
      _pointerDown = null;
      _setPressed(false);
    }
  }

  void _onPointerEnd(PointerEvent event) {
    _pointerDown = null;
    _setPressed(false);
  }

  @override
  void didUpdateWidget(covariant SacPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _pressed) {
      _pressed = false;
      _pointerDown = null;
    }
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
        onPointerDown: widget.enabled ? _onPointerDown : null,
        onPointerMove: widget.enabled ? _onPointerMove : null,
        onPointerUp: widget.enabled ? _onPointerEnd : null,
        onPointerCancel: widget.enabled ? _onPointerEnd : null,
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
        onLongPress: widget.enabled ? widget.onLongPress : null,
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

/// Tap target with the dashboard press scale.
///
/// Keeps the [InkWell] arguments that call sites already pass. Splash,
/// highlight, and border shape are not painted.
class SacInkWell extends StatelessWidget {
  const SacInkWell({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.customBorder,
    this.splashColor,
    this.highlightColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;
  final ShapeBorder? customBorder;
  final Color? splashColor;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    final active = onTap != null || onLongPress != null;
    return Semantics(
      button: active,
      enabled: active,
      onTap: onTap,
      onLongPress: onLongPress,
      child: SacPressable(
        onTap: onTap,
        onLongPress: onLongPress,
        enabled: active,
        child: child,
      ),
    );
  }
}

/// Material [Tab] whose label scales on press. [TabBar] still owns the tap.
Tab sacPressTab(String label) {
  return Tab(
    child: SacPressable(
      listenOnly: true,
      child: Text(
        label,
        softWrap: false,
        overflow: TextOverflow.fade,
      ),
    ),
  );
}
