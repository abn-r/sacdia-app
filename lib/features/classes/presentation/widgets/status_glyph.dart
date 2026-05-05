import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/class_requirement.dart';
import '../utils/status_meta.dart';

/// Glifo circular 22×22 que representa visualmente el [RequirementStatus].
///
/// Cinco variantes definidas en el handoff §5.10:
/// - **validado**: círculo sólido verde con check blanco.
/// - **enviado**: círculo bg `sentBg` con borde `sentColor` y avión de papel.
/// - **observado**: círculo bg `observedBg` con borde `observedColor` y "!" bold.
/// - **rechazado**: círculo sólido rosa con X blanca.
/// - **pendiente**: círculo blanco con borde dashed `ink300`.
///
/// Incluye [Semantics] con el label de estado para accesibilidad (VoiceOver /
/// TalkBack), de modo que el color no es la única señal.
class StatusGlyph extends StatelessWidget {
  final RequirementStatus status;

  /// Tamaño del glifo. Por defecto 22 (handoff).
  final double size;

  const StatusGlyph({
    super.key,
    required this.status,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    final meta = StatusMeta.of(status);

    return Semantics(
      label: meta.label,
      excludeSemantics: true,
      child: _buildGlyph(),
    );
  }

  Widget _buildGlyph() {
    switch (status) {
      case RequirementStatus.validado:
        return _SolidGlyph(
          size: size,
          bg: AppColors.validatedColor,
          child: _CheckIcon(size: size),
        );

      case RequirementStatus.enviado:
        return _BorderedGlyph(
          size: size,
          bg: AppColors.sentBg,
          borderColor: AppColors.sentColor,
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedSent,
            size: size * 0.5,
            color: AppColors.sentColor,
          ),
        );

      case RequirementStatus.observado:
        return _BorderedGlyph(
          size: size,
          bg: AppColors.observedBg,
          borderColor: AppColors.observedColor,
          child: Text(
            '!',
            style: TextStyle(
              fontSize: size * 0.59,
              fontWeight: FontWeight.w800,
              color: AppColors.observedDark,
              height: 1,
            ),
          ),
        );

      case RequirementStatus.rechazado:
        return _SolidGlyph(
          size: size,
          bg: AppColors.rejectedColor,
          child: _XIcon(size: size),
        );

      case RequirementStatus.pendiente:
        return _DashedGlyph(size: size);
    }
  }
}

// ── Solid circle ──────────────────────────────────────────────────────────────

class _SolidGlyph extends StatelessWidget {
  final double size;
  final Color bg;
  final Widget child;

  const _SolidGlyph({
    required this.size,
    required this.bg,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      child: Center(child: child),
    );
  }
}

// ── Bordered circle ────────────────────────────────────────────────────────────

class _BorderedGlyph extends StatelessWidget {
  final double size;
  final Color bg;
  final Color borderColor;
  final Widget child;

  const _BorderedGlyph({
    required this.size,
    required this.bg,
    required this.borderColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Center(child: child),
    );
  }
}

// ── Dashed circle (pending) ───────────────────────────────────────────────────

class _DashedGlyph extends StatelessWidget {
  final double size;

  const _DashedGlyph({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _DashedCirclePainter(),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;
    final paint = Paint()
      ..color = AppColors.ink300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw dashed circle
    const dashCount = 12;
    const dashLength = 0.35; // radians
    const gapLength = 0.18; // radians

    for (int i = 0; i < dashCount; i++) {
      final start = i * (dashLength + gapLength);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start - (3.14159 / 2), // start from top
        dashLength,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Icon helpers ──────────────────────────────────────────────────────────────

/// Check mark (validated state)
class _CheckIcon extends StatelessWidget {
  final double size;

  const _CheckIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size * 0.55, size * 0.55),
      painter: _CheckPainter(),
    );
  }
}

class _CheckPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(size.width * 0.15, size.height * 0.52)
      ..lineTo(size.width * 0.42, size.height * 0.76)
      ..lineTo(size.width * 0.85, size.height * 0.24);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// X mark (rejected state)
class _XIcon extends StatelessWidget {
  final double size;

  const _XIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size * 0.5, size * 0.5),
      painter: _XPainter(),
    );
  }
}

class _XPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.2),
      Offset(size.width * 0.8, size.height * 0.8),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.8, size.height * 0.2),
      Offset(size.width * 0.2, size.height * 0.8),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
