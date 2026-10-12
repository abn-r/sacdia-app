import 'package:flutter/material.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';

/// Adds (M14) and removes (M13) a review row without a jump.
///
/// Rows grow and fade in when [animateIn] is set, and fade and collapse once
/// [visible] turns false. The parent drops the row from its list after the
/// animation. Reduced Motion keeps the fade and removes the resize, so the gap
/// closes in one step when the row leaves.
class ImportRowPresence extends StatefulWidget {
  const ImportRowPresence({
    super.key,
    required this.child,
    this.visible = true,
    this.animateIn = false,
  });

  final Widget child;
  final bool visible;
  final bool animateIn;

  @override
  State<ImportRowPresence> createState() => _ImportRowPresenceState();
}

class _ImportRowPresenceState extends State<ImportRowPresence> {
  late bool _entered = !widget.animateIn;

  @override
  void initState() {
    super.initState();
    if (!_entered) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _entered = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final open = widget.visible && _entered;
    final reduce = SacMotion.reduceMotionOf(context);
    final faded = AnimatedOpacity(
      opacity: open ? 1 : 0,
      duration: open ? SacMotion.standard : SacMotion.reducedFade,
      curve: SacMotion.easeOut,
      child: widget.child,
    );
    if (reduce) return faded;
    return AnimatedSize(
      duration: SacMotion.standard,
      curve: SacMotion.easeOut,
      alignment: Alignment.topCenter,
      child: ClipRect(
        child: Align(
          heightFactor: open ? 1 : 0,
          alignment: Alignment.topCenter,
          child: faded,
        ),
      ),
    );
  }
}
