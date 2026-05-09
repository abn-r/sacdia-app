import 'package:flutter/material.dart';

/// Punto verde con halo pulsante — indicador "verificado en vivo".
/// Cumple la función anti-screenshot (combínalo con LiveClock).
class VerifiedDot extends StatefulWidget {
  final Color color;
  final double size;
  const VerifiedDot({
    super.key,
    this.color = const Color(0xFF86EFAC),
    this.size = 8,
  });

  @override
  State<VerifiedDot> createState() => _VerifiedDotState();
}

class _VerifiedDotState extends State<VerifiedDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (_, __) {
              final t = _c.value;
              return Container(
                width: widget.size * (1 + t * 1.6),
                height: widget.size * (1 + t * 1.6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withAlpha((0.5 * (1 - t) * 255).round()),
                ),
              );
            },
          ),
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
              boxShadow: [BoxShadow(color: widget.color, blurRadius: 8)],
            ),
          ),
        ],
      ),
    );
  }
}
