import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';

import 'credencial_tokens.dart';

const credentialParallaxTransformKey = Key('credential-parallax-transform');

/// Subtle touch-driven parallax wrapper for the digital credential.
///
/// Uses raw pointer events instead of gesture recognizers so it does not steal
/// taps from children such as the QR. When the platform requests reduced
/// motion, the child is rendered without transform.
class CredentialParallax extends StatefulWidget {
  const CredentialParallax({
    super.key,
    required this.child,
    this.enabled = true,
    this.maxTilt = 0.055,
    this.maxTranslate = 4,
    this.borderRadius = CredencialTokens.rImmersive,
  });

  final Widget child;
  final bool enabled;
  final double maxTilt;
  final double maxTranslate;
  final double borderRadius;

  @override
  State<CredentialParallax> createState() => _CredentialParallaxState();
}

class _CredentialParallaxState extends State<CredentialParallax> {
  Offset _position = Offset.zero;
  bool _isInteracting = false;

  void _updateFromGlobalPosition(Offset globalPosition) {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;

    final local = renderObject.globalToLocal(globalPosition);
    final size = renderObject.size;
    if (size.width <= 0 || size.height <= 0) return;

    final dx = ((local.dx / size.width) * 2 - 1).clamp(-1.0, 1.0);
    final dy = ((local.dy / size.height) * 2 - 1).clamp(-1.0, 1.0);

    setState(() {
      _isInteracting = true;
      _position = Offset(dx, dy);
    });
  }

  void _reset() {
    if (!_isInteracting && _position == Offset.zero) return;
    setState(() {
      _isInteracting = false;
      _position = Offset.zero;
    });
  }

  Matrix4 _transformFor(Offset position) {
    if (position == Offset.zero) return Matrix4.identity();

    final tiltX = -position.dy * widget.maxTilt;
    final tiltY = position.dx * widget.maxTilt;

    return Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..rotateX(tiltX)
      ..rotateY(tiltY);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && !SacMotion.reduceMotionOf(context);

    if (!enabled) return widget.child;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) => _updateFromGlobalPosition(event.position),
      onPointerMove: (event) => _updateFromGlobalPosition(event.position),
      onPointerUp: (_) => _reset(),
      onPointerCancel: (_) => _reset(),
      child: AnimatedContainer(
        key: credentialParallaxTransformKey,
        duration:
            _isInteracting ? const Duration(milliseconds: 80) : SacMotion.modal,
        curve: SacMotion.easeOut,
        transform: _transformFor(_position),
        transformAlignment: Alignment.center,
        child: Transform.translate(
          offset: Offset(
            _position.dx * widget.maxTranslate,
            _position.dy * widget.maxTranslate,
          ),
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              widget.child,
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _isInteracting ? 1 : 0.35,
                    duration: SacMotion.standard,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(
                              math.max(-1, -0.35 + _position.dx * 0.45),
                              math.max(-1, -0.65 + _position.dy * 0.35),
                            ),
                            end: Alignment(
                              math.min(1, 0.75 + _position.dx * 0.35),
                              math.min(1, 0.55 + _position.dy * 0.25),
                            ),
                            colors: [
                              Colors.white.withAlpha(0x00),
                              Colors.white.withAlpha(0x14),
                              Colors.white.withAlpha(0x00),
                            ],
                            stops: const [0.18, 0.48, 0.78],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
