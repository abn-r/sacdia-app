import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';

/// Staggered list entrance: fade + slide-up, [SacMotion] tokens.
///
/// Wraps list items in a fade + slide-up that fires sequentially
/// based on the item [index].
///
/// Usage:
/// ```dart
/// ListView.builder(
///   itemBuilder: (context, index) {
///     return StaggeredListItem(
///       index: index,
///       child: MyCard(...),
///     );
///   },
/// )
/// ```

/// A single animated list item that fades in and slides up.
///
/// Triggers on first build. Stagger is [SacMotion.stagger] (40ms) per index,
/// capped at index 5. Duration is [SacMotion.standard] (200ms).
/// Set [animate] to false to opt out. Reduced Motion skips movement.
class StaggeredListItem extends StatefulWidget {
  final Widget child;

  /// Position in the list — drives the stagger delay.
  final int index;

  /// Base delay before the first item starts animating.
  final Duration initialDelay;

  /// Delay added per item index.
  final Duration staggerDelay;

  /// Total animation duration for each item.
  final Duration duration;

  /// Vertical offset the item slides up from (pixels).
  final double slideOffset;

  /// Whether to animate. Pass false to respect reduced-motion preferences.
  final bool animate;

  const StaggeredListItem({
    super.key,
    required this.child,
    required this.index,
    this.initialDelay = Duration.zero,
    this.staggerDelay = SacMotion.stagger,
    this.duration = SacMotion.standard,
    this.slideOffset = 8.0,
    this.animate = true,
  });

  @override
  State<StaggeredListItem> createState() => _StaggeredListItemState();
}

class _StaggeredListItemState extends State<StaggeredListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  Timer? _delayedStart;
  bool? _reduceMotion;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fade = CurvedAnimation(
      parent: _controller,
      curve: SacMotion.easeOut,
    );

    _slide = Tween<Offset>(
      begin: Offset(0, widget.slideOffset / 100),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: SacMotion.easeOut,
    ));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = SacMotion.reduceMotionOf(context);
    if (_reduceMotion == reduceMotion) return;

    final firstDependencyRead = _reduceMotion == null;
    _reduceMotion = reduceMotion;

    if (reduceMotion || !widget.animate) {
      _delayedStart?.cancel();
      _controller.value = 1.0;
    } else if (firstDependencyRead) {
      _scheduleStart();
    }
  }

  void _scheduleStart() {
    // Cap individual item delay so frequent lists stay snappy.
    final cappedIndex = widget.index.clamp(0, 5);
    final delay = widget.initialDelay + widget.staggerDelay * cappedIndex;
    _delayedStart = Timer(delay, () {
      if (mounted && _reduceMotion == false) _controller.forward();
    });
  }

  @override
  void dispose() {
    _delayedStart?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate || _reduceMotion == true) return widget.child;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

/// Convenience widget that wraps an entire list of children with staggered
/// entrance animations. Suitable for Column-based layouts (e.g. dashboard cards).
///
/// Usage:
/// ```dart
/// StaggeredColumn(
///   children: [ClubInfoCard(), CurrentClassCard(), QuickStatsCard()],
/// )
/// ```
class StaggeredColumn extends StatelessWidget {
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;
  final Duration initialDelay;
  final Duration staggerDelay;
  final Duration duration;
  final double slideOffset;
  final bool animate;

  const StaggeredColumn({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.min,
    this.initialDelay = Duration.zero,
    this.staggerDelay = SacMotion.stagger,
    this.duration = SacMotion.standard,
    this.slideOffset = 8.0,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    // Respect system reduced-motion preference.
    final mediaQuery = MediaQuery.of(context);
    final shouldAnimate = animate && !mediaQuery.disableAnimations;

    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: [
        for (int i = 0; i < children.length; i++)
          StaggeredListItem(
            index: i,
            initialDelay: initialDelay,
            staggerDelay: staggerDelay,
            duration: duration,
            slideOffset: slideOffset,
            animate: shouldAnimate,
            child: children[i],
          ),
      ],
    );
  }
}
