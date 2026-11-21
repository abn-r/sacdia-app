import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_network_image.dart';

/// The picture of an achievement in full colour, in its own silhouette.
///
/// It never reshapes the badge: `BoxFit.contain`, and only the height is
/// given to the image cache (fixing both sides decodes the file into a box
/// and flattens square badges). Grey/dimmed looks are applied by the caller
/// (`SacBadgeTint`). Falls back to the initials of [name] when the badge has
/// no image or fails to load.
class AchievementArt extends StatelessWidget {
  const AchievementArt({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.height,
    required this.fallbackColor,
    this.width,
  });

  final String? imageUrl;
  final String name;
  final double height;

  /// Box width; defaults to 5:4 so wide badges are not squeezed.
  final double? width;

  /// Tint of the initials mark.
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    final boxWidth = width ?? height * 1.25;
    final image = imageUrl?.trim() ?? '';
    final fallback = _InitialsMark(
      initials: achievementInitials(name),
      color: fallbackColor,
      width: boxWidth,
      height: height,
    );
    if (image.isEmpty) return fallback;

    return ClipRect(
      child: SacNetworkImage(
        imageUrl: image,
        width: boxWidth,
        height: height,
        fit: BoxFit.contain,
        memCacheHeight: (height * 3).round(),
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }
}

class _InitialsMark extends StatelessWidget {
  const _InitialsMark({
    required this.initials,
    required this.color,
    required this.width,
    required this.height,
  });

  final String initials;
  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(color: color.withAlpha(60), width: 1.5),
        ),
        child: Center(
          child: Text(
            initials,
            style: TextStyle(
              fontSize: SacFontSize.headlineLarge,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

String achievementInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
}

/// Drawing of a secret achievement that is not obtained yet: a dashed medal
/// with a question mark. The same one in the grid and in the detail sheet.
class SecretBadgeArt extends StatelessWidget {
  const SecretBadgeArt({super.key, required this.height});

  final double height;

  /// Width / height of the drawing (a 64 x 72 medal).
  static const double aspect = 64 / 72;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return ExcludeSemantics(
      child: SizedBox(
        width: height * aspect,
        height: height,
        child: CustomPaint(
          painter: _SecretBadgePainter(
            fill: c.surfaceVariant,
            line: c.textTertiary.withValues(alpha: 0.55),
            mark: c.textTertiary,
          ),
        ),
      ),
    );
  }
}

class _SecretBadgePainter extends CustomPainter {
  const _SecretBadgePainter({
    required this.fill,
    required this.line,
    required this.mark,
  });

  final Color fill;
  final Color line;
  final Color mark;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.height / 72;
    canvas.save();
    canvas.scale(s);

    // Ribbon.
    final ribbon = Path()
      ..moveTo(22, 2)
      ..lineTo(42, 2)
      ..lineTo(39, 14)
      ..lineTo(25, 14)
      ..close();
    canvas.drawPath(ribbon, Paint()..color = line);

    // Medal body with a dashed outline.
    const center = Offset(32, 42);
    canvas.drawCircle(center, 27, Paint()..color = fill);
    final circle = Path()..addOval(Rect.fromCircle(center: center, radius: 27));
    final stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final PathMetric metric in circle.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 4), stroke);
        distance += 8;
      }
    }

    // Question mark.
    final painter = TextPainter(
      text: TextSpan(
        text: '?',
        style: TextStyle(
          fontSize: size.height * 0.36 / s,
          fontWeight: FontWeight.w700,
          color: mark,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_SecretBadgePainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.line != line ||
      oldDelegate.mark != mark;
}
