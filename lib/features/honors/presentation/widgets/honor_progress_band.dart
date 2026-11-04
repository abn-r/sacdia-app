import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_badge_image.dart';

/// Stage of a member's honor on the four-step path.
enum HonorWorkStep { enrolled, working, inReview, validated }

/// The path step for [userHonor]: IN_PROGRESS and REJECTED are still
/// "working", PENDING_REVIEW is in review, APPROVED is validated.
HonorWorkStep honorWorkStepFor(UserHonor userHonor) {
  if (userHonor.isCompleted) return HonorWorkStep.validated;
  if (userHonor.isUnderReview) return HonorWorkStep.inReview;
  return HonorWorkStep.working;
}

/// Header band of the in-progress honor screen: patch inside a progress ring,
/// names, percentage and the four-step path.
///
/// Paints [bandColor] edge to edge and always uses white text, so the caller
/// must pass a color that holds 4.5:1 against white (see `bandColorFor`).
/// [topInset] is the space the overlaid top bar occupies.
class HonorProgressBand extends StatelessWidget {
  const HonorProgressBand({
    super.key,
    required this.bandColor,
    required this.honorName,
    required this.progress,
    required this.metaLabel,
    required this.step,
    required this.topInset,
    this.categoryName,
    this.imageUrl,
    this.bottomPadding = 34,
  });

  final Color bandColor;
  final String honorName;
  final String? categoryName;
  final String? imageUrl;

  /// 0..1.
  final double progress;

  /// Line under the name, e.g. "40% · Dentro de la app".
  final String metaLabel;
  final HonorWorkStep step;
  final double topInset;

  /// Room left under the content for tabs that float over the band edge.
  final double bottomPadding;

  static const double _patchSize = 64;
  static const double _ringSize = 84;
  static const double _ringStroke = 5;

  @override
  Widget build(BuildContext context) {
    final white90 = Colors.white.withValues(alpha: 0.9);
    final text = Theme.of(context).textTheme;
    final category = categoryName;

    return Container(
      key: const ValueKey('honor-progress-band'),
      width: double.infinity,
      color: bandColor,
      padding: EdgeInsets.fromLTRB(20, topInset + 4, 20, bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _PatchRing(
                progress: progress,
                imageUrl: imageUrl,
                size: _ringSize,
                patchSize: _patchSize,
                stroke: _ringStroke,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (category != null && category.isNotEmpty)
                      Text(
                        category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(color: white90),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      honorName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Semantics(
                      label: 'honors.requirements.band_progress_semantics'
                          .tr(namedArgs: {
                        'percent': '${(progress * 100).round()}',
                      }),
                      excludeSemantics: true,
                      child: Text(
                        metaLabel,
                        style: text.bodySmall?.copyWith(color: white90),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          HonorStepPath(step: step),
        ],
      ),
    );
  }
}

class _PatchRing extends StatelessWidget {
  const _PatchRing({
    required this.progress,
    required this.imageUrl,
    required this.size,
    required this.patchSize,
    required this.stroke,
  });

  final double progress;
  final String? imageUrl;
  final double size;
  final double patchSize;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final duration =
        SacMotion.reduceMotionOf(context) ? Duration.zero : SacMotion.modal;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: progress.clamp(0.0, 1.0)),
            duration: duration,
            curve: SacMotion.easeOut,
            builder: (context, value, _) => CustomPaint(
              size: Size.square(size),
              painter: _RingPainter(value: value, stroke: stroke),
            ),
          ),
          ExcludeSemantics(
            child: HonorBadgeImage(
              imageUrl: imageUrl,
              width: patchSize,
              height: patchSize,
              fallbackColor: Colors.white,
              fallbackBackgroundColor: Colors.white.withValues(alpha: 0.18),
              fallbackBorderRadius: BorderRadius.circular(AppTheme.radiusFull),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.value, required this.stroke});

  final double value;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.width - stroke) / 2;
    final track = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, track);
    if (value <= 0) return;
    final arc = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * value,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.stroke != stroke;
}

/// Four equal segments: Inscrita, Trabajando, En revisión, Validada. Segments
/// up to [step] are white; the rest are faded. Screen readers get one label
/// naming the current step.
class HonorStepPath extends StatelessWidget {
  const HonorStepPath({super.key, required this.step});

  final HonorWorkStep step;

  static List<String> labels() => [
        'honors.detail.status_enrolled'.tr(),
        'honors.requirements.step_working'.tr(),
        'honors.detail.status_sent'.tr(),
        'honors.detail.status_validated'.tr(),
      ];

  @override
  Widget build(BuildContext context) {
    final names = labels();
    final text = Theme.of(context).textTheme;
    final current = step.index;

    return Semantics(
      container: true,
      label: 'honors.requirements.step_semantics'.tr(namedArgs: {
        'current': '${current + 1}',
        'total': '${names.length}',
        'label': names[current],
      }),
      excludeSemantics: true,
      child: Row(
        key: const ValueKey('honor-step-path'),
        children: [
          for (var i = 0; i < names.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= current
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.3),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusHairline),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    names[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(
                      color: i <= current
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.75),
                      fontWeight:
                          i == current ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
