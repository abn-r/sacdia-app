import 'package:flutter/material.dart';

import '../../animations/motion_tokens.dart';

/// Keeps the evidence footer on screen while it leaves: when [visible] turns
/// false the last child slides down and fades out ([SacMotion.modal],
/// [SacMotion.drawer]) instead of vanishing, then it is dropped.
///
/// Never shown means never built. Reduced Motion drops the slide and keeps a
/// short fade.
class EvidenceFooterPresence extends StatefulWidget {
  const EvidenceFooterPresence({
    super.key,
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  State<EvidenceFooterPresence> createState() => _EvidenceFooterPresenceState();
}

class _EvidenceFooterPresenceState extends State<EvidenceFooterPresence> {
  Widget? _last;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    _gone = !widget.visible;
  }

  @override
  void didUpdateWidget(EvidenceFooterPresence oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && _gone) _gone = false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.visible) _last = widget.child;
    final child = _last;
    if (_gone || child == null) return const SizedBox.shrink();

    final reduce = SacMotion.reduceMotionOf(context);
    final duration = reduce ? SacMotion.reducedFade : SacMotion.modal;
    final visible = widget.visible;
    return AnimatedSlide(
      offset: visible || reduce ? Offset.zero : const Offset(0, 1),
      duration: duration,
      curve: SacMotion.drawer,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: duration,
        curve: SacMotion.drawer,
        onEnd: () {
          if (!widget.visible && mounted) setState(() => _gone = true);
        },
        child: IgnorePointer(ignoring: !visible, child: child),
      ),
    );
  }
}
