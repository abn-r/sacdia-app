import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

/// Text-link blue for the carousel (Omitir, Ya tengo cuenta): same token as
/// the auth links, with enough contrast in both themes.
Color welcomeLinkColor(BuildContext context) => context.sac.link;

/// Title (24/w700, tight, centered) with the emphasis fragment in brand blue,
/// followed by the body copy. The emphasis never breaks across lines.
class WelcomeCopy extends StatelessWidget {
  const WelcomeCopy({
    super.key,
    required this.title,
    required this.emphasis,
    required this.body,
    this.animateIn = false,
  });

  final String title;
  final String emphasis;
  final String body;
  final bool animateIn;

  static const Curve _curve = Cubic(0.2, 0.8, 0.2, 1);
  static const double _rise = 12;
  static const Duration _duration = Duration(milliseconds: 750);

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final theme = Theme.of(context).textTheme;
    final titleStyle = theme.displaySmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      height: 1.2,
      color: c.text,
    );
    final bodyStyle = theme.titleMedium?.copyWith(
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: c.textSecondary,
    );
    final lead = title.trimRight();
    final trimmedEmphasis = emphasis.trim();

    Widget compose(double titleP, double bodyP) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Rise(
            progress: titleP,
            child: Semantics(
              header: true,
              label: '$lead $trimmedEmphasis',
              excludeSemantics: true,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '$lead '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: Text(
                        trimmedEmphasis,
                        softWrap: false,
                        style: titleStyle?.copyWith(
                          color: AppColors.loginBrandBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: titleStyle,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _Rise(
            progress: bodyP,
            child: Text(
              body,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: bodyStyle,
            ),
          ),
        ],
      );
    }

    if (!animateIn || SacMotion.reduceMotionOf(context)) {
      return compose(1, 1);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: _duration,
      builder: (context, v, _) {
        final seconds = v * _duration.inMilliseconds / 1000;
        double step(double start) =>
            _curve.transform(((seconds - start) / 0.5).clamp(0.0, 1.0));
        return compose(step(0.15), step(0.25));
      },
    );
  }
}

class _Rise extends StatelessWidget {
  const _Rise({required this.progress, required this.child});

  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (progress >= 1) return child;
    return Opacity(
      opacity: progress,
      child: Transform.translate(
        offset: Offset(0, WelcomeCopy._rise * (1 - progress)),
        child: child,
      ),
    );
  }
}

/// Six segments (18x4, the active one 30x4, finished ones at 35%). The whole
/// row is 44pt tall and every segment jumps to its page.
class WelcomeProgress extends StatelessWidget {
  const WelcomeProgress({
    super.key,
    required this.count,
    required this.index,
    required this.onSelect,
  });

  final int count;
  final int index;
  final ValueChanged<int>? onSelect;

  static const double rowHeight = 44;
  static const double _segmentWidth = 18;
  static const double _activeWidth = 30;
  static const double _segmentHeight = 4;
  static const double _gap = 6;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final reduce = SacMotion.reduceMotionOf(context);
    return SizedBox(
      height: rowHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            Semantics(
              button: true,
              selected: i == index,
              label: 'welcome_carousel.page_semantics'.tr(
                namedArgs: {'current': '${i + 1}', 'total': '$count'},
              ),
              excludeSemantics: true,
              onTap: onSelect == null ? null : () => onSelect!(i),
              child: GestureDetector(
                key: Key('welcome-progress-$i'),
                behavior: HitTestBehavior.opaque,
                onTap: onSelect == null ? null : () => onSelect!(i),
                child: SizedBox(
                  height: rowHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _gap / 2),
                    child: Center(
                      child: AnimatedContainer(
                        duration: reduce ? Duration.zero : SacMotion.routeEnter,
                        curve: SacMotion.easeOut,
                        width: i == index ? _activeWidth : _segmentWidth,
                        height: _segmentHeight,
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusHairline),
                          color: i == index
                              ? AppColors.loginBrandBlue
                              : i < index
                                  ? AppColors.loginBrandBlue
                                      .withValues(alpha: 0.35)
                                  : c.ink200,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
