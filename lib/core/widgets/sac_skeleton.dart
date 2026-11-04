import 'package:flutter/material.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

/// Shared shimmer for loading skeletons.
///
/// Sweeps a `skeleton -> skeletonHighlight -> skeleton` gradient over every
/// painted pixel of [child], so wrap a tree made only of skeleton blocks
/// ([SacSkeletonBox], [SacSkeletonCard], or `Container`s filled with
/// `context.sac.skeleton`). Use ONE shimmer around a whole skeleton screen,
/// not one per block. Static when reduce motion is on or [enabled] is false.
///
/// Gotcha: the animation repeats forever, so widget tests must use
/// `pump(duration)`, never `pumpAndSettle()`, unless reduce motion is on.
///
/// ```dart
/// SacShimmer(child: Column(children: [SacSkeletonBox(height: 16)]))
/// ```
class SacShimmer extends StatefulWidget {
  const SacShimmer({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<SacShimmer> createState() => _SacShimmerState();
}

class _SacShimmerState extends State<SacShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  bool get _animate => widget.enabled && !SacMotion.reduceMotionOf(context);

  void _sync() {
    if (_animate) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(SacShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_animate) return widget.child;
    final c = context.sac;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          child: widget.child,
          builder: (context, child) {
            final t = _controller.value;
            return ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (bounds) => LinearGradient(
                colors: [c.skeleton, c.skeletonHighlight, c.skeleton],
                stops: const [0.2, 0.5, 0.8],
                begin: Alignment(-1.5 + 3 * t, 0),
                end: Alignment(-0.5 + 3 * t, 0),
              ).createShader(bounds),
              child: child,
            );
          },
        ),
      ),
    );
  }
}

/// Flat skeleton block filled with `context.sac.skeleton`.
///
/// [width] null means "fill the available width".
///
/// ```dart
/// const SacSkeletonBox(width: 120, height: 14)
/// ```
class SacSkeletonBox extends StatelessWidget {
  const SacSkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = AppTheme.radiusXS,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.sac.skeleton,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Generic list-row skeleton: optional leading circle plus [lines] text bars.
///
/// Builds a shrink-wrapped `ListView` inside ONE [SacShimmer], so it works as
/// a page body, inside a `Column`/`Expanded`, and as the child of a
/// `RefreshIndicator` (default [scrollable] true uses
/// `AlwaysScrollableScrollPhysics`, so pull-to-refresh still triggers). Pass
/// `scrollable: false` when nesting it in another scroll view.
///
/// ```dart
/// const SacSkeletonList(itemCount: 8, lines: 2)
/// ```
class SacSkeletonList extends StatelessWidget {
  const SacSkeletonList({
    super.key,
    this.itemCount = 6,
    this.leading = true,
    this.lines = 2,
    this.padding,
    this.scrollable = true,
  });

  final int itemCount;
  final bool leading;
  final int lines;
  final EdgeInsetsGeometry? padding;

  /// true: [AlwaysScrollableScrollPhysics] (RefreshIndicator works).
  /// false: [NeverScrollableScrollPhysics] (inside another scrollable).
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    return SacShimmer(
      child: ExcludeSemantics(
        child: ListView.separated(
          shrinkWrap: true,
          padding: padding ?? const EdgeInsets.all(16),
          physics: scrollable
              ? const AlwaysScrollableScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          itemCount: itemCount,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (_, __) => _SkeletonRow(leading: leading, lines: lines),
        ),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({required this.leading, required this.lines});

  final bool leading;
  final int lines;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (leading) ...[
          const SacSkeletonBox(width: 44, height: 44, radius: 22),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < lines; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                FractionallySizedBox(
                  widthFactor: i == 0 ? 0.6 : (i == lines - 1 ? 0.4 : 0.85),
                  child: SacSkeletonBox(height: i == 0 ? 14 : 12),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Rounded skeleton block for card grids.
///
/// Does not animate by itself: wrap the whole grid in one [SacShimmer].
///
/// ```dart
/// SacShimmer(child: GridView.count(crossAxisCount: 2, children: [
///   for (var i = 0; i < 4; i++) const SacSkeletonCard(),
/// ]))
/// ```
class SacSkeletonCard extends StatelessWidget {
  const SacSkeletonCard({super.key, this.height = 120});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SacSkeletonBox(height: height, radius: AppTheme.radiusMD);
  }
}
