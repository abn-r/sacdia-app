import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import 'medico_tokens.dart';

/// Widget de deslizamiento para confirmar una acción crítica.
///
/// El usuario debe arrastrar el thumb hacia la derecha más del 75% del ancho
/// para que la acción se dispare. Si suelta antes del umbral, el thumb
/// regresa a la posición inicial con animación.
///
/// Diseñado para el botón "LLAMAR 911" en [MedicalSosView].
class SlideToConfirmButton extends StatefulWidget {
  /// Etiqueta principal del botón.
  final String label;

  /// Sublabel opcional mostrado debajo del label principal.
  final String? subLabel;

  /// Color de fondo de la pista.
  final Color trackColor;

  /// Color del thumb deslizable.
  final Color thumbColor;

  /// Color del ícono del thumb.
  final Color thumbIconColor;

  /// Color del texto sobre la pista.
  final Color textColor;

  /// Altura total del botón.
  final double height;

  /// Callback que se dispara al completar el deslizamiento.
  final VoidCallback onConfirmed;

  const SlideToConfirmButton({
    super.key,
    required this.label,
    this.subLabel,
    required this.trackColor,
    required this.thumbColor,
    required this.thumbIconColor,
    required this.textColor,
    this.height = 72,
    required this.onConfirmed,
  });

  @override
  State<SlideToConfirmButton> createState() => _SlideToConfirmButtonState();
}

class _SlideToConfirmButtonState extends State<SlideToConfirmButton>
    with SingleTickerProviderStateMixin {
  double _thumbOffset = 0;
  bool _isDragging = false;
  late AnimationController _snapController;
  late Animation<double> _snapAnimation;
  double _trackWidth = 0;

  static const double _thumbSize = 52;
  static const double _trackPadding = 8;
  static const double _confirmThreshold = 0.75;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _snapAnimation = CurvedAnimation(
      parent: _snapController,
      curve: Curves.easeOutBack,
    );
    _snapController.addListener(() {
      if (!_isDragging) {
        setState(() {
          _thumbOffset = _snapAnimation.value;
        });
      }
    });
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  double get _maxOffset => _trackWidth - _thumbSize - _trackPadding * 2;

  void _onDragStart(DragStartDetails _) {
    _snapController.stop();
    setState(() => _isDragging = true);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    setState(() {
      _thumbOffset = (_thumbOffset + details.delta.dx)
          .clamp(0.0, _maxOffset.clamp(0.0, double.infinity));
    });
  }

  void _onDragEnd(DragEndDetails _) {
    setState(() => _isDragging = false);

    if (_maxOffset <= 0) return;

    final progress = _thumbOffset / _maxOffset;
    if (progress >= _confirmThreshold) {
      // Triggered — snap to end then call back
      HapticFeedback.heavyImpact();
      setState(() => _thumbOffset = _maxOffset);
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          widget.onConfirmed();
          // Reset after callback
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _resetThumb();
          });
        }
      });
    } else {
      // Not far enough — snap back
      _resetThumb();
    }
  }

  void _resetThumb() {
    final from = _thumbOffset;
    _snapAnimation = Tween<double>(begin: from, end: 0).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOutBack),
    );
    _snapController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return LayoutBuilder(
      builder: (context, constraints) {
        _trackWidth = constraints.maxWidth;

        return SizedBox(
          height: widget.height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(MedicoTokens.rPill),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // ── Track background ──────────────────────────────────────
                Container(
                  width: double.infinity,
                  height: widget.height,
                  decoration: BoxDecoration(
                    color: widget.trackColor,
                    borderRadius: BorderRadius.circular(MedicoTokens.rPill),
                  ),
                ),

                // ── Progress fill (drag feedback) ─────────────────────────
                if (!reduceMotion)
                  Positioned(
                    left: 0,
                    child: Container(
                      width: _thumbOffset + _thumbSize + _trackPadding,
                      height: widget.height,
                      decoration: BoxDecoration(
                        color: widget.thumbColor.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(MedicoTokens.rPill),
                      ),
                    ),
                  ),

                // ── Label ─────────────────────────────────────────────────
                Positioned.fill(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: _thumbSize + 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.label,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: widget.textColor,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.subLabel != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.subLabel!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: widget.textColor.withValues(alpha: 0.75),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // ── Draggable thumb ───────────────────────────────────────
                Positioned(
                  left: _trackPadding + _thumbOffset,
                  child: GestureDetector(
                    onHorizontalDragStart: _onDragStart,
                    onHorizontalDragUpdate: _onDragUpdate,
                    onHorizontalDragEnd: _onDragEnd,
                    child: Container(
                      width: _thumbSize,
                      height: _thumbSize,
                      decoration: BoxDecoration(
                        color: widget.thumbColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: widget.thumbColor.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedArrowRight01,
                        color: widget.thumbIconColor,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
