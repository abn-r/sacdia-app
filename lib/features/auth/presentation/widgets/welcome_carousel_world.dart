import 'package:flutter/material.dart';

/// Paisaje del emblema de Aventureros, expandido: cielo, cerros, iglesia.
enum WelcomeWorldKind { clubs, classes, honors, admin, journey }

class WelcomeWorldPainter extends CustomPainter {
  const WelcomeWorldPainter(this.kind);

  final WelcomeWorldKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF7EC4EA),
          Color(0xFFC5E8F6),
          Color(0xFFFFF3D6),
          Color(0xFFFFFFFF),
        ],
        stops: [0.0, 0.36, 0.68, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    final sun = Offset(w * 0.5, h * 0.2);
    canvas.drawCircle(
      sun,
      38,
      Paint()..color = const Color(0x66FFE08A),
    );
    canvas.drawCircle(
      sun,
      20,
      Paint()..color = const Color(0xFFFFE9A8),
    );

    _hill(canvas, size, y: 0.46, lift: 0.1, color: const Color(0xFF9EC9B0));
    _hill(canvas, size, y: 0.52, lift: 0.12, color: const Color(0xFF7BB36A));

    if (kind == WelcomeWorldKind.journey) {
      _windingPath(canvas, size);
      _summitCross(canvas, Offset(w * 0.62, h * 0.34), h * 0.12);
    } else {
      _church(canvas, Offset(w * 0.8, h * 0.5), h * 0.26);
    }

    _hill(canvas, size, y: 0.62, lift: 0.08, color: const Color(0xFF4F9644));

    _pine(canvas, Offset(w * 0.08, h * 0.6), h * 0.16);
    _pine(canvas, Offset(w * 0.16, h * 0.64), h * 0.2);
    _pine(canvas, Offset(w * 0.9, h * 0.58), h * 0.18);
    _pine(canvas, Offset(w * 0.94, h * 0.62), h * 0.14);
  }

  void _hill(
    Canvas canvas,
    Size size, {
    required double y,
    required double lift,
    required Color color,
  }) {
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * y)
      ..cubicTo(
        size.width * 0.22,
        size.height * (y - lift),
        size.width * 0.48,
        size.height * (y + lift * 0.35),
        size.width * 0.7,
        size.height * y,
      )
      ..quadraticBezierTo(
        size.width * 0.88,
        size.height * (y - lift * 0.4),
        size.width,
        size.height * (y + lift * 0.15),
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _windingPath(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.42, size.height)
      ..quadraticBezierTo(
        size.width * 0.38,
        size.height * 0.78,
        size.width * 0.48,
        size.height * 0.62,
      )
      ..quadraticBezierTo(
        size.width * 0.58,
        size.height * 0.48,
        size.width * 0.62,
        size.height * 0.4,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFD7A56A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFE8C48A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
  }

  void _summitCross(Canvas canvas, Offset c, double h) {
    final p = Paint()
      ..color = const Color(0xFF5A4030)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c, Offset(c.dx, c.dy + h), p);
    canvas.drawLine(
      Offset(c.dx - h * 0.28, c.dy + h * 0.18),
      Offset(c.dx + h * 0.28, c.dy + h * 0.18),
      p,
    );
  }

  void _church(Canvas canvas, Offset base, double h) {
    final bodyW = h * 0.52;
    final bodyH = h * 0.5;
    final body = Rect.fromCenter(
      center: Offset(base.dx, base.dy - bodyH / 2),
      width: bodyW,
      height: bodyH,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(3)),
      Paint()..color = const Color(0xFFF7F4EE),
    );

    final roof = Path()
      ..moveTo(body.left - 5, body.top + 10)
      ..lineTo(body.center.dx, body.top - h * 0.16)
      ..lineTo(body.right + 5, body.top + 10)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFF3E734C));

    final steepleTop = Offset(body.center.dx, body.top - h * 0.28);
    final steeple = Path()
      ..moveTo(body.center.dx - 6, body.top + 4)
      ..lineTo(steepleTop.dx, steepleTop.dy)
      ..lineTo(body.center.dx + 6, body.top + 4)
      ..close();
    canvas.drawPath(steeple, Paint()..color = const Color(0xFF2F5C3C));

    final cross = Paint()
      ..color = const Color(0xFFF8F6F0)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(steepleTop.dx, steepleTop.dy - 12),
      Offset(steepleTop.dx, steepleTop.dy + 6),
      cross,
    );
    canvas.drawLine(
      Offset(steepleTop.dx - 6, steepleTop.dy - 4),
      Offset(steepleTop.dx + 6, steepleTop.dy - 4),
      cross,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(body.center.dx, body.bottom - bodyH * 0.18),
          width: bodyW * 0.22,
          height: bodyH * 0.34,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF6B5344),
    );
    canvas.drawCircle(
      Offset(body.center.dx, body.top + bodyH * 0.38),
      4.5,
      Paint()..color = const Color(0xFF8EC8EA),
    );
  }

  void _pine(Canvas canvas, Offset base, double h) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(base.dx, base.dy - h * 0.08),
          width: h * 0.1,
          height: h * 0.22,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF6B4A32),
    );
    final green = Paint()..color = const Color(0xFF2E7A40);
    for (var i = 0; i < 3; i++) {
      final top = Offset(base.dx, base.dy - h * (0.28 + i * 0.2));
      final spread = h * (0.28 - i * 0.04);
      final leaf = Path()
        ..moveTo(top.dx, top.dy - h * 0.18)
        ..lineTo(top.dx - spread, top.dy + h * 0.1)
        ..lineTo(top.dx + spread, top.dy + h * 0.1)
        ..close();
      canvas.drawPath(leaf, green);
    }
  }

  @override
  bool shouldRepaint(WelcomeWorldPainter oldDelegate) =>
      oldDelegate.kind != kind;
}

/// Hojas al frente, como el marco del mock.
class WelcomeFoliagePainter extends CustomPainter {
  const WelcomeFoliagePainter();

  @override
  void paint(Canvas canvas, Size size) {
    _cluster(canvas, Offset(-10, size.height * 0.78), 70);
    _cluster(canvas, Offset(28, size.height * 0.92), 54);
    _cluster(canvas, Offset(size.width + 8, size.height * 0.8), 76);
    _cluster(canvas, Offset(size.width - 36, size.height * 0.94), 50);
  }

  void _cluster(Canvas canvas, Offset c, double r) {
    canvas.drawOval(
      Rect.fromCenter(center: c, width: r * 1.6, height: r),
      Paint()..color = const Color(0xFF3E8A48),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(r * 0.28, -r * 0.18),
        width: r * 1.1,
        height: r * 0.75,
      ),
      Paint()..color = const Color(0xFF2F6F3A),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(-r * 0.2, r * 0.1),
        width: r * 0.9,
        height: r * 0.55,
      ),
      Paint()..color = const Color(0xFF5AAA55),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WelcomePng extends StatelessWidget {
  const WelcomePng({
    super.key,
    required this.asset,
    required this.size,
  });

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cache =
        (size * MediaQuery.devicePixelRatioOf(context)).round().clamp(32, 320);
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      cacheWidth: cache,
      excludeFromSemantics: true,
    );
  }
}

/// Celular de escena. Adentro va UI viva, no un JPG.
double welcomeDeviceWidth(BoxConstraints c) {
  final fromHeight = c.maxHeight / 2.08;
  final fromWidth = c.maxWidth * 0.5;
  return (fromHeight < fromWidth ? fromHeight : fromWidth).clamp(148.0, 210.0);
}

class WelcomeDevice extends StatelessWidget {
  const WelcomeDevice({
    super.key,
    required this.child,
    required this.width,
  });

  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    final h = width * 1.92;
    const bezel = Color(0xFF1A2330);

    return Container(
      width: width,
      height: h,
      decoration: BoxDecoration(
        color: bezel,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            offset: const Offset(0, 18),
            blurRadius: 32,
            spreadRadius: -4,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(7, 10, 7, 10),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: ColoredBox(
                color: Colors.white,
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: width - 14,
                    height: h - 20,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                width: width * 0.28,
                height: 9,
                decoration: BoxDecoration(
                  color: bezel,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WelcomeFlag extends StatelessWidget {
  const WelcomeFlag({
    super.key,
    required this.cloth,
    required this.emblem,
    required this.height,
  });

  final Color cloth;
  final String emblem;
  final double height;

  @override
  Widget build(BuildContext context) {
    final w = height * 0.72;
    return SizedBox(
      width: w,
      height: height,
      child: Stack(
        children: [
          CustomPaint(
            size: Size(w, height),
            painter: _PennantPainter(cloth),
          ),
          Positioned(
            left: height * 0.16,
            top: height * 0.12,
            child: WelcomePng(asset: emblem, size: height * 0.28),
          ),
        ],
      ),
    );
  }
}

class _PennantPainter extends CustomPainter {
  const _PennantPainter(this.cloth);

  final Color cloth;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, 5, size.height),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF6B4A32),
    );
    final flag = Path()
      ..moveTo(5, 6)
      ..lineTo(size.width, size.height * 0.2)
      ..lineTo(size.width * 0.78, size.height * 0.36)
      ..lineTo(5, size.height * 0.5)
      ..close();
    canvas.drawPath(flag, Paint()..color = cloth);
    canvas.drawPath(
      flag,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_PennantPainter oldDelegate) => oldDelegate.cloth != cloth;
}

abstract final class WelcomeEmblem {
  static const aventureros = 'assets/img/logo_aventureros_color.png';
  static const conquistadores = 'assets/img/logo_conquistadores_color.png';
  static const guiasMayores = 'assets/img/logo-guias-mayores.png';
  static const sash = 'assets/img/barra_ave.png';
}

/// Color de tela, no el del logo recortado.
abstract final class WelcomeFlagCloth {
  static const aventureros = Color(0xFF1E6BB5);
  static const conquistadores = Color(0xFFC62828);
  static const guiasMayores = Color(0xFF1B6B3A);
}
