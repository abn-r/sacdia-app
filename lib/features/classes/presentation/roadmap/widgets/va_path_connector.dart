import 'package:flutter/material.dart';
import '../theme/roadmap_tokens.dart';

/// Conector serpenteante (curva en S) entre dos nodos consecutivos.
/// Replica `VAPathConnector` de la versión web.
class VAPathConnector extends StatelessWidget {
  final String side; // 'left' | 'right' del nodo destino
  final String prevSide; // lado del nodo origen
  final Color accentColor;

  const VAPathConnector({
    super.key,
    required this.side,
    required this.prevSide,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: -(RoadmapTokens.pathHeight + 80),
      height: RoadmapTokens.pathHeight,
      child: IgnorePointer(
        child: CustomPaint(
          painter: _SerpentinePainter(
            side: side,
            prevSide: prevSide,
            color: accentColor,
          ),
        ),
      ),
    );
  }
}

class _SerpentinePainter extends CustomPainter {
  final String side;
  final String prevSide;
  final Color color;

  _SerpentinePainter(
      {required this.side, required this.prevSide, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Coords basadas en frame de 402px; escalar al ancho real.
    final double scale = size.width / RoadmapTokens.frameWidth;
    final double startX = (prevSide == 'left' ? 98.0 : 314.0) * scale;
    final double endX = (side == 'left' ? 98.0 : 314.0) * scale;
    final bool goingRight = startX < endX;
    final double H = size.height;

    // Curva tipo S: control 1 hacia atrás, control 2 hacia adelante.
    final double c1x = goingRight ? startX - 60 * scale : startX + 60 * scale;
    final double c2x = goingRight ? endX + 60 * scale : endX - 60 * scale;

    final Path path = Path()
      ..moveTo(startX, 0)
      ..cubicTo(c1x, H * 0.45, c2x, H * 0.55, endX, H);

    // Línea punteada: dash 2, gap 12 (en unidades del path)
    final Path dashed = _dashPath(path, dashArray: [2, 12]);

    final paint = Paint()
      ..color = color.withValues(alpha: RoadmapTokens.pathOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = RoadmapTokens.pathStrokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(dashed, paint);
  }

  @override
  bool shouldRepaint(_SerpentinePainter old) =>
      old.side != side || old.prevSide != prevSide || old.color != color;

  Path _dashPath(Path source, {required List<double> dashArray}) {
    final Path dest = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      int idx = 0;
      while (distance < metric.length) {
        final double len = dashArray[idx % dashArray.length];
        if (draw) {
          dest.addPath(
              metric.extractPath(distance, distance + len), Offset.zero);
        }
        distance += len;
        idx++;
        draw = !draw;
      }
    }
    return dest;
  }
}
