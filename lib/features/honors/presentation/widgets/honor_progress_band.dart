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

/// Header band of the honor screens: patch, names, an optional status
/// [badge], a meta line and the four-step path.
///
/// The patch never gets a ring: honor patches come in many shapes (oval,
/// round, triangle, star) and a circle around them reads poorly. [progress]
/// fills the current step of the path instead.
///
/// Paints [bandColor] edge to edge and always uses white text, so the caller
/// must pass a color that holds 4.5:1 against white (see `bandColorFor`).
/// [topInset] is the space the overlaid top bar occupies.
class HonorProgressBand extends StatelessWidget {
  const HonorProgressBand({
    super.key,
    required this.bandColor,
    required this.honorName,
    required this.metaLabel,
    required this.step,
    required this.topInset,
    this.progress,
    this.badge,
    this.categoryName,
    this.imageUrl,
    this.bottomPadding = 34,
  });

  final Color bandColor;
  final String honorName;
  final String? categoryName;
  final String? imageUrl;

  /// 0..1 of the work done. Fills the "working" step of the path; null when
  /// there is nothing to measure yet.
  final double? progress;

  /// Status pill shown before the meta line (e.g. "Validada"). It brings its
  /// own background, so it holds contrast on any band color.
  final Widget? badge;

  /// Line under the name, e.g. "40% · Dentro de la app".
  final String metaLabel;

  /// Last step reached; null when none is (the honor is not enrolled yet).
  final HonorWorkStep? step;
  final double topInset;

  /// Room left under the content for tabs that float over the band edge.
  final double bottomPadding;

  static const double _patchSize = 108;

  Widget _meta(TextTheme text, Color color) {
    final line = Text(metaLabel, style: text.bodySmall?.copyWith(color: color));
    final value = progress;
    if (value == null) return line;
    return Semantics(
      label: 'honors.requirements.band_progress_semantics'.tr(namedArgs: {
        'percent': '${(value * 100).round()}',
      }),
      excludeSemantics: true,
      child: line,
    );
  }

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
              ExcludeSemantics(
                child: HonorBadgeImage(
                  imageUrl: imageUrl,
                  width: _patchSize,
                  height: _patchSize,
                  fallbackColor: Colors.white,
                  fallbackBackgroundColor: Colors.white.withValues(alpha: 0.18),
                  fallbackBorderRadius:
                      BorderRadius.circular(AppTheme.radiusFull),
                ),
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (badge != null) badge!,
                        _meta(text, white90),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          HonorStepPath(step: step, progress: progress),
        ],
      ),
    );
  }
}

/// Four equal segments: Inscrita, Trabajando, En revisión, Validada. Segments
/// before [step] are white and the rest are faded. The current step is white
/// too, except "working" with a [progress]: it fills only that far. Screen
/// readers get one label naming the current step.
class HonorStepPath extends StatelessWidget {
  const HonorStepPath({super.key, required this.step, this.progress});

  /// Null when no step is reached yet (not enrolled).
  final HonorWorkStep? step;

  /// 0..1 of the work done; only the "working" step shows it.
  final double? progress;

  double _fill(int index, int current) {
    if (index < current) return 1;
    if (index > current) return 0;
    final value = progress;
    if (step == HonorWorkStep.working && value != null) {
      return value.clamp(0.0, 1.0);
    }
    return 1;
  }

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
    final current = step?.index ?? -1;

    return Semantics(
      container: true,
      label: current < 0
          ? 'honors.detail.step_none_semantics'.tr()
          : 'honors.requirements.step_semantics'.tr(namedArgs: {
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
                  _StepSegment(
                    key: ValueKey('honor-step-segment-$i'),
                    fill: _fill(i, current),
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

/// One segment of the path: a faded track with a white fill that animates to
/// [fill] (0..1).
class _StepSegment extends StatelessWidget {
  const _StepSegment({super.key, required this.fill});

  final double fill;

  @override
  Widget build(BuildContext context) {
    final duration =
        SacMotion.reduceMotionOf(context) ? Duration.zero : SacMotion.modal;
    final radius = BorderRadius.circular(AppTheme.radiusHairline);
    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.3),
        borderRadius: radius,
      ),
      alignment: Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: fill),
        duration: duration,
        curve: SacMotion.easeOut,
        builder: (context, value, _) => FractionallySizedBox(
          widthFactor: value,
          heightFactor: 1,
          child: DecoratedBox(
            decoration:
                BoxDecoration(color: Colors.white, borderRadius: radius),
          ),
        ),
      ),
    );
  }
}
