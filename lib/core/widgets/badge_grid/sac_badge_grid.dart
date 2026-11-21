import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';

import 'sac_badge_card.dart';

/// Three-column grid of [SacBadgeCard]s with equal-height rows at any text
/// scale and a one-time entrance (fade + rise, staggered).
///
/// The entrance plays only for the cards built while the grid first shows;
/// cards built later (scrolling, a refresh that keeps this grid mounted) just
/// appear. Cards are tracked by [keyOf], so a card that moves keeps its state
/// (and its grey-to-colour transition).
class SacBadgeGrid extends StatefulWidget {
  const SacBadgeGrid({
    super.key,
    required this.itemCount,
    required this.keyOf,
    required this.itemBuilder,
    this.padding = const EdgeInsets.all(16),
    this.physics,
    this.shrinkWrap = false,
    this.artHeight = SacBadgeCard.defaultArtHeight,
  });

  final int itemCount;

  /// Stable identity of the card at an index (an id, not the index).
  final Key Function(int index) keyOf;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final double artHeight;

  /// Cards past this position appear at once.
  static const int entranceCap = 9;

  static const double spacing = 8;

  @override
  State<SacBadgeGrid> createState() => _SacBadgeGridState();
}

class _EntranceWindow {
  bool closed = false;

  bool claims(int index) => !closed && index < SacBadgeGrid.entranceCap;
}

class _SacBadgeGridState extends State<SacBadgeGrid> {
  final _window = _EntranceWindow();
  Timer? _close;

  @override
  void initState() {
    super.initState();
    // Longest entrance: the last staggered card plus its own duration.
    _close = Timer(
      SacMotion.entrance + SacMotion.entranceStagger * 6,
      () => _window.closed = true,
    );
  }

  @override
  void dispose() {
    _close?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final extent = SacBadgeCard.heightFor(
      MediaQuery.textScalerOf(context),
      artHeight: widget.artHeight,
    );
    final keys = [for (var i = 0; i < widget.itemCount; i++) widget.keyOf(i)];
    final indexOfKey = {
      for (var i = 0; i < keys.length; i++) keys[i]: i,
    };

    return GridView.builder(
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      padding: widget.padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisExtent: extent,
        crossAxisSpacing: SacBadgeGrid.spacing,
        mainAxisSpacing: SacBadgeGrid.spacing,
      ),
      itemCount: widget.itemCount,
      findChildIndexCallback: (key) => indexOfKey[key],
      itemBuilder: (context, index) => _EntranceCell(
        key: keys[index],
        index: index,
        window: _window,
        child: widget.itemBuilder(context, index),
      ),
    );
  }
}

/// Decides once, when it is built, whether this card takes part in the
/// entrance, so a rebuild never adds or removes the animation wrapper (that
/// would reset the card's state).
class _EntranceCell extends StatefulWidget {
  const _EntranceCell({
    super.key,
    required this.index,
    required this.window,
    required this.child,
  });

  final int index;
  final _EntranceWindow window;
  final Widget child;

  @override
  State<_EntranceCell> createState() => _EntranceCellState();
}

class _EntranceCellState extends State<_EntranceCell> {
  late final bool _animate = widget.window.claims(widget.index);
  late final int _index = widget.index;

  @override
  Widget build(BuildContext context) {
    return SacEntrance(
      index: _animate ? _index : SacBadgeGrid.entranceCap,
      maxAnimated: SacBadgeGrid.entranceCap,
      child: widget.child,
    );
  }
}
