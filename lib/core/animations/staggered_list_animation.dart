import 'package:flutter/material.dart';

/// Duolingo-style staggered list animation utilities.
///
/// Wraps list items in a fade + slide-up entrance that fires sequentially
/// based on the item [index], creating a cascading reveal effect.
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
/// The animation triggers automatically when the widget first builds.
/// [index] controls the stagger delay (50ms per item, capped at 600ms).
/// Set [animate] to false to opt-out for accessibility (reduced-motion).
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
    this.staggerDelay = const Duration(milliseconds: 60),
    this.duration = const Duration(milliseconds: 350),
    this.slideOffset = 24.0,
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

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slide = Tween<Offset>(
      begin: Offset(0, widget.slideOffset / 100),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    if (widget.animate) {
      // Cap individual item delay so very long lists don't feel broken.
      final cappedIndex = widget.index.clamp(0, 10);
      final delay = widget.initialDelay +
          widget.staggerDelay * cappedIndex;
      Future.delayed(delay, () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) return widget.child;

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
    this.initialDelay = const Duration(milliseconds: 80),
    this.staggerDelay = const Duration(milliseconds: 70),
    this.duration = const Duration(milliseconds: 350),
    this.slideOffset = 28.0,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    // Respect system reduced-motion preference.
    final mediaQuery = MediaQuery.of(context);
    final shouldAnimate =
        animate && !mediaQuery.disableAnimations;

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
