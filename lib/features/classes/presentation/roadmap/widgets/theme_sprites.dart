import 'package:flutter/material.dart';

/// Sprites temáticos pintados con CustomPainter (sin assets externos).
/// Se distribuyen por banda según el tipo de track:
/// - 'av' (Aventureros): naturaleza infantil — árboles, flores, mariposas
/// - 'cq' (Conquistadores): campamento — pinos, tiendas, brújula, mochila
/// - 'gm' (Guías Mayores): noche — fogata, linternas, montañas, banderines
class ThemeSpritesBackground extends StatelessWidget {
  final String kind; // 'av' | 'cq' | 'gm'
  final double height;

  const ThemeSpritesBackground({
    super.key,
    required this.kind,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final List<_Sprite> sprites = _generateSprites(kind, height);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: IgnorePointer(
        child: Stack(
          children: sprites.map((s) {
            return Positioned(
              top: s.top,
              left: s.left,
              right: s.right,
              child: Opacity(
                opacity: 0.55,
                child: CustomPaint(
                  size: Size(s.size, s.size * s.aspect),
                  painter: _SpritePainter(kind: s.kind, color: s.color),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  List<_Sprite> _generateSprites(String kind, double H) {
    final List<_Sprite> out = [];
    if (kind == 'av') {
      out.addAll([
        _Sprite(
            top: H * .04,
            left: 8,
            kind: 'tree',
            color: const Color(0xFF7BCC9C),
            size: 38),
        _Sprite(
            top: H * .10,
            right: 6,
            kind: 'tree',
            color: const Color(0xFF4F8A56),
            size: 42),
        _Sprite(
            top: H * .18,
            left: 14,
            kind: 'bush',
            color: const Color(0xFF7BCC9C),
            size: 32),
        _Sprite(
            top: H * .22,
            right: 20,
            kind: 'flower',
            color: const Color(0xFFEF6B5C),
            size: 18),
        _Sprite(
            top: H * .30,
            left: 18,
            kind: 'mushroom',
            color: const Color(0xFFD14B66),
            size: 22),
        _Sprite(
            top: H * .38,
            right: 12,
            kind: 'butterfly',
            color: const Color(0xFFA99BD2),
            size: 22),
        _Sprite(
            top: H * .50,
            left: 8,
            kind: 'rabbit',
            color: const Color(0xFFEFE3D2),
            size: 26),
        _Sprite(
            top: H * .60,
            right: 18,
            kind: 'bush',
            color: const Color(0xFF8FD4AF),
            size: 36),
        _Sprite(
            top: H * .72,
            right: 8,
            kind: 'tree',
            color: const Color(0xFF7BCC9C),
            size: 36),
        _Sprite(
            top: H * .86,
            left: 22,
            kind: 'mushroom',
            color: const Color(0xFFC56B7E),
            size: 20),
      ]);
    } else if (kind == 'cq') {
      out.addAll([
        _Sprite(
            top: H * .04,
            left: 6,
            kind: 'tree',
            color: const Color(0xFF3F6B45),
            size: 56),
        _Sprite(
            top: H * .08,
            right: 8,
            kind: 'tree',
            color: const Color(0xFF4F8A56),
            size: 48),
        _Sprite(
            top: H * .18,
            left: 18,
            kind: 'tent',
            color: const Color(0xFF5A7FA8),
            size: 48),
        _Sprite(
            top: H * .26,
            right: 14,
            kind: 'compass',
            color: const Color(0xFFC99036),
            size: 26),
        _Sprite(
            top: H * .36,
            left: 12,
            kind: 'tree',
            color: const Color(0xFF3F6B45),
            size: 44),
        _Sprite(
            top: H * .46,
            right: 8,
            kind: 'backpack',
            color: const Color(0xFF8B5A3C),
            size: 32),
        _Sprite(
            top: H * .56,
            right: 16,
            kind: 'tent',
            color: const Color(0xFFC99036),
            size: 42),
        _Sprite(
            top: H * .68,
            left: 16,
            kind: 'tree',
            color: const Color(0xFF4F8A56),
            size: 50),
        _Sprite(
            top: H * .82,
            right: 6,
            kind: 'tree',
            color: const Color(0xFF3F6B45),
            size: 54),
      ]);
    } else if (kind == 'gm') {
      out.addAll([
        _Sprite(
            top: H * .04,
            right: 8,
            kind: 'mountain',
            color: const Color(0xFF6B7280),
            size: 84),
        _Sprite(
            top: H * .14,
            left: 14,
            kind: 'tree',
            color: const Color(0xFF3F6B45),
            size: 50),
        _Sprite(
            top: H * .22,
            right: 20,
            kind: 'lantern',
            color: const Color(0xFFFFC857),
            size: 24),
        _Sprite(
            top: H * .32,
            left: 18,
            kind: 'campfire',
            color: const Color(0xFFFF8A3D),
            size: 44),
        _Sprite(
            top: H * .48,
            right: 12,
            kind: 'tent',
            color: const Color(0xFFB8453A),
            size: 50),
        _Sprite(
            top: H * .62,
            left: 10,
            kind: 'lantern',
            color: const Color(0xFFFFC857),
            size: 22),
        _Sprite(
            top: H * .76,
            right: 6,
            kind: 'mountain',
            color: const Color(0xFF5C6470),
            size: 92),
      ]);
    }
    return out;
  }
}

class _Sprite {
  final double top;
  final double? left;
  final double? right;
  final String kind;
  final Color color;
  final double size;
  // Relación de aspecto — siempre 1:1 (cuadrado) para todos los sprites actuales.
  final double aspect = 1.0;
  _Sprite({
    required this.top,
    this.left,
    this.right,
    required this.kind,
    required this.color,
    required this.size,
  });
}

class _SpritePainter extends CustomPainter {
  final String kind;
  final Color color;

  _SpritePainter({required this.kind, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final w = size.width, h = size.height;

    switch (kind) {
      case 'tree':
        // triangulo + tronco
        final triPath = Path()
          ..moveTo(w * .5, 0)
          ..lineTo(w, h * .85)
          ..lineTo(0, h * .85)
          ..close();
        canvas.drawPath(triPath, paint);
        canvas.drawRect(
          Rect.fromLTWH(w * .42, h * .85, w * .16, h * .15),
          Paint()..color = const Color(0xFF7B5530),
        );
        break;
      case 'bush':
        canvas.drawCircle(Offset(w * .3, h * .6), w * .3, paint);
        canvas.drawCircle(Offset(w * .7, h * .6), w * .3, paint);
        canvas.drawCircle(Offset(w * .5, h * .4), w * .35, paint);
        break;
      case 'flower':
        final stem = Paint()
          ..color = const Color(0xFF4F8A56)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
        canvas.drawLine(Offset(w * .5, h), Offset(w * .5, h * .4), stem);
        for (int i = 0; i < 5; i++) {
          final px = w * .5 + (w * .25) * 0.9 * (i % 2 == 0 ? 1 : -1);
          canvas.drawCircle(Offset(px, h * .3), w * .12, paint);
        }
        canvas.drawCircle(Offset(w * .5, h * .3), w * .12,
            Paint()..color = const Color(0xFFFFD93D));
        break;
      case 'mushroom':
        canvas.drawArc(
          Rect.fromLTWH(0, 0, w, h * .7),
          3.14,
          3.14,
          true,
          paint,
        );
        canvas.drawRect(
          Rect.fromLTWH(w * .35, h * .45, w * .3, h * .55),
          Paint()..color = Colors.white,
        );
        // puntos
        canvas.drawCircle(
            Offset(w * .35, h * .25), w * .08, Paint()..color = Colors.white);
        canvas.drawCircle(
            Offset(w * .65, h * .3), w * .07, Paint()..color = Colors.white);
        break;
      case 'butterfly':
        canvas.drawCircle(Offset(w * .3, h * .4), w * .25, paint);
        canvas.drawCircle(Offset(w * .7, h * .4), w * .25, paint);
        canvas.drawCircle(Offset(w * .3, h * .65), w * .2, paint);
        canvas.drawCircle(Offset(w * .7, h * .65), w * .2, paint);
        canvas.drawRect(
          Rect.fromLTWH(w * .47, h * .3, w * .06, h * .5),
          Paint()..color = Colors.black87,
        );
        break;
      case 'rabbit':
        canvas.drawOval(Rect.fromLTWH(w * .15, h * .4, w * .7, h * .55), paint);
        canvas.drawCircle(Offset(w * .3, h * .35), w * .18, paint);
        // orejas
        canvas.drawOval(Rect.fromLTWH(w * .22, 0, w * .12, h * .4), paint);
        canvas.drawOval(Rect.fromLTWH(w * .36, 0, w * .12, h * .4), paint);
        // ojo
        canvas.drawCircle(
            Offset(w * .25, h * .35), w * .03, Paint()..color = Colors.black87);
        break;
      case 'tent':
        final tentPath = Path()
          ..moveTo(w * .5, 0)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close();
        canvas.drawPath(tentPath, paint);
        // entrada
        final doorPath = Path()
          ..moveTo(w * .5, h * .2)
          ..lineTo(w * .65, h)
          ..lineTo(w * .35, h)
          ..close();
        canvas.drawPath(
            doorPath, Paint()..color = Colors.black.withValues(alpha: 0.3));
        break;
      case 'compass':
        canvas.drawCircle(Offset(w * .5, h * .5), w * .45,
            Paint()..color = const Color(0xFFE8D9B5));
        canvas.drawCircle(
            Offset(w * .5, h * .5),
            w * .45,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
        // aguja
        final needle = Path()
          ..moveTo(w * .5, h * .15)
          ..lineTo(w * .55, h * .5)
          ..lineTo(w * .5, h * .85)
          ..lineTo(w * .45, h * .5)
          ..close();
        canvas.drawPath(needle, Paint()..color = const Color(0xFFB8453A));
        break;
      case 'backpack':
        final body = RRect.fromRectAndRadius(
          Rect.fromLTWH(w * .15, h * .25, w * .7, h * .7),
          Radius.circular(w * .15),
        );
        canvas.drawRRect(body, paint);
        // asa
        canvas.drawArc(
          Rect.fromLTWH(w * .3, h * .05, w * .4, h * .35),
          3.14,
          3.14,
          false,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * .08,
        );
        break;
      case 'mountain':
        final m = Path()
          ..moveTo(0, h)
          ..lineTo(w * .35, h * .2)
          ..lineTo(w * .55, h * .55)
          ..lineTo(w * .75, h * .15)
          ..lineTo(w, h)
          ..close();
        canvas.drawPath(m, paint);
        // nieve
        final snow = Path()
          ..moveTo(w * .28, h * .35)
          ..lineTo(w * .35, h * .2)
          ..lineTo(w * .42, h * .35)
          ..close();
        canvas.drawPath(
            snow, Paint()..color = Colors.white.withValues(alpha: 0.7));
        break;
      case 'lantern':
        // marco
        canvas.drawRect(Rect.fromLTWH(w * .2, h * .25, w * .6, h * .55),
            Paint()..color = const Color(0xFF6B5538));
        // luz
        canvas.drawRect(Rect.fromLTWH(w * .3, h * .35, w * .4, h * .35), paint);
        // top
        canvas.drawRect(Rect.fromLTWH(w * .15, h * .15, w * .7, h * .12),
            Paint()..color = const Color(0xFF6B5538));
        // gancho
        canvas.drawLine(
            Offset(w * .5, 0),
            Offset(w * .5, h * .15),
            Paint()
              ..color = const Color(0xFF6B5538)
              ..strokeWidth = 2);
        break;
      case 'campfire':
        // logs
        canvas.drawLine(
            Offset(0, h * .85),
            Offset(w, h * .85),
            Paint()
              ..color = const Color(0xFF6B4423)
              ..strokeWidth = w * .15
              ..strokeCap = StrokeCap.round);
        // flama externa
        final flame = Path()
          ..moveTo(w * .5, h * .1)
          ..quadraticBezierTo(w * .9, h * .5, w * .5, h * .8)
          ..quadraticBezierTo(w * .1, h * .5, w * .5, h * .1);
        canvas.drawPath(flame, paint);
        // flama interna
        final inner = Path()
          ..moveTo(w * .5, h * .35)
          ..quadraticBezierTo(w * .7, h * .55, w * .5, h * .75)
          ..quadraticBezierTo(w * .3, h * .55, w * .5, h * .35);
        canvas.drawPath(inner, Paint()..color = const Color(0xFFFFD93D));
        break;
    }
  }

  @override
  bool shouldRepaint(_SpritePainter old) => false;
}
