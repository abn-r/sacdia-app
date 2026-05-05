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
      top: RoadmapTokens.connectorSlotTopOffset,
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
    // ── X anchor derivation (frame 402 px) ──────────────────────────────────
    // Layout: each node row has Padding(left: nodePadInside|nodePadOutside,
    //         right: nodePadOutside|nodePadInside) + Align(centerLeft/Right)
    //         containing a SizedBox(width: 148).
    //
    // Left node center X:
    //   paddingLeft(24) + nodeWidth(148)/2 = 24 + 74 = 98
    //
    // Right node center X:
    //   frameWidth(402) - paddingRight(24) - nodeWidth(148)/2
    //   = 402 - 24 - 74 = 304
    //
    // (Previous code had 314 for the right side — 10 px off.)
    // ────────────────────────────────────────────────────────────────────────
    final double scale = size.width / RoadmapTokens.frameWidth;
    const double leftNodeCenterX = 98.0; // derived above
    const double rightNodeCenterX = 304.0; // derived above (was 314, corrected)

    final double startX =
        (prevSide == 'left' ? leftNodeCenterX : rightNodeCenterX) * scale;
    final double endX =
        (side == 'left' ? leftNodeCenterX : rightNodeCenterX) * scale;
    final bool goingRight = startX < endX;

    // Vertical inset: curve starts/ends slightly inside the connector slot
    // rather than at the raw y=0 / y=H edge, so it visually tucks under the
    // shield bottom and emerges from the shield top of the next node.
    final double inset = RoadmapTokens.connectorVerticalInset;
    final double H = size.height;

    // Curva tipo S: control 1 hacia atrás, control 2 hacia adelante.
    final double c1x = goingRight ? startX - 60 * scale : startX + 60 * scale;
    final double c2x = goingRight ? endX + 60 * scale : endX - 60 * scale;

    final Path path = Path()
      ..moveTo(startX, inset)
      ..cubicTo(c1x, H * 0.45, c2x, H * 0.55, endX, H - inset);

    // Línea punteada: dash 3, gap 8 (más densa que antes: [2,12])
    final Path dashed = _dashPath(path, dashArray: [3, 8]);

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
