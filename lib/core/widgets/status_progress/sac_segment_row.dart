import 'package:flutter/material.dart';

import '../../animations/motion_tokens.dart';

/// One piece of a [SacSegmentRow]: its weight and color.
class SacSegmentPart {
  const SacSegmentPart(this.weight, this.color);

  final int weight;
  final Color color;
}

/// Row of weighted colored segments that grows from empty on first build and
/// glides to the new weights when they change. Only the widths of plain
/// [ColoredBox]es move; with Reduced Motion it shows the final state at once.
///
/// Parts with a zero weight are left out and the gap goes only between the
/// ones drawn. The parent decides the height and the clip.
class SacSegmentRow extends StatefulWidget {
  const SacSegmentRow({super.key, required this.parts, this.gap = 3});

  final List<SacSegmentPart> parts;
  final double gap;

  @override
  State<SacSegmentRow> createState() => _SacSegmentRowState();
}

class _SacSegmentRowState extends State<SacSegmentRow>
    with SingleTickerProviderStateMixin {
  static const _scale = 1000;

  late final AnimationController _controller;
  late final Animation<double> _curve;
  late List<double> _from;
  late List<double> _to;
  bool? _reduceMotion;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: SacMotion.standard);
    _curve = CurvedAnimation(parent: _controller, curve: SacMotion.easeOut);
    _to = _fractions(widget.parts);
    _from = List<double>.filled(_to.length, 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = SacMotion.reduceMotionOf(context);
    if (_reduceMotion == reduce) return;
    final first = _reduceMotion == null;
    _reduceMotion = reduce;
    if (reduce) {
      _controller.value = 1;
    } else if (first) {
      _controller.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(SacSegmentRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _fractions(widget.parts);
    if (_sameFractions(next, _to)) return;
    final current = _displayed();
    _from = current.length == next.length
        ? current
        : List<double>.filled(next.length, 0);
    _to = next;
    if (_reduceMotion == true) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static List<double> _fractions(List<SacSegmentPart> parts) {
    final total = parts.fold<int>(0, (s, p) => s + p.weight);
    return [for (final p in parts) total == 0 ? 0.0 : p.weight / total];
  }

  static bool _sameFractions(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() > 1e-9) return false;
    }
    return true;
  }

  List<double> _displayed() {
    final t = _curve.value;
    return [
      for (var i = 0; i < _to.length; i++) _from[i] + (_to[i] - _from[i]) * t
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, _) {
        final shown = _displayed();
        final children = <Widget>[];
        var used = 0;
        for (var i = 0; i < _to.length; i++) {
          if (_to[i] <= 0 && shown[i] <= 0.0005) continue;
          final flex = (shown[i] * _scale).round().clamp(1, _scale);
          used += flex;
          if (children.isNotEmpty) children.add(SizedBox(width: widget.gap));
          children.add(
            Expanded(
              flex: flex,
              child: ColoredBox(color: widget.parts[i].color),
            ),
          );
        }
        if (used < _scale && children.isNotEmpty) {
          children.add(Spacer(flex: _scale - used));
        }
        return Row(
          // Without stretch an empty ColoredBox is 0 tall.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      },
    );
  }
}
