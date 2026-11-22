import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../animations/motion_tokens.dart';
import '../../theme/app_theme.dart';
import '../../theme/sac_colors.dart';
import '../sac_pressable.dart';
import 'sac_status_style.dart';

/// Where an item stands right now, in a card (like [SacCard]) with an icon tile tinted by [style]: the
/// current state, one line of context and a small "Step N of M". It does not
/// draw the whole path; tapping it opens the list of every state (see
/// [showSacStatesSheet]). A chevron says it is tappable.
///
/// Unlike [SacStatusPanel] it never shows a progress path: the owner wants
/// one state at a time and the rest one tap away.
class SacStatePanel extends StatefulWidget {
  const SacStatePanel({
    super.key,
    required this.style,
    required this.title,
    this.onTap,
    this.message,
    this.stepLabel,
    this.semanticsHint,
    this.semanticsLabel,
    this.stateKey,
  });

  final SacStatusStyle style;

  /// Already translated name of the current state.
  final String title;

  /// One line of context under the title.
  final String? message;

  /// "Step 2 of 4", already translated.
  final String? stepLabel;

  /// Screen reader hint for the tap ("Shows every state").
  final String? semanticsHint;

  /// Replaces the default spoken label (title, message and step joined), e.g.
  /// "State: Sent, step 2 of 3". Already translated.
  final String? semanticsLabel;

  /// Identifies the state for the cross-fade: the panel animates only when
  /// this changes. Defaults to [title]. Set it when the title carries a live
  /// number ("Uploading 64 %") that must update without re-animating.
  final String? stateKey;

  /// Null: a read-only panel (no ripple, no chevron, not a button).
  final VoidCallback? onTap;

  @override
  State<SacStatePanel> createState() => _SacStatePanelState();
}

/// One-off effect on the icon after the state changed.
enum _IconEffect { none, nudge, draw }

class _SacStatePanelState extends State<SacStatePanel> {
  _IconEffect _effect = _IconEffect.none;

  static String _keyOf(SacStatePanel w) =>
      '${w.stateKey ?? w.title}|${w.style.container.toARGB32()}';

  @override
  void didUpdateWidget(SacStatePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_keyOf(oldWidget) == _keyOf(widget)) return;
    // Only a real change into "sent" (nudge) or "validated" (draw).
    _effect = switch (widget.style.kind) {
      SacStatusKind.review => _IconEffect.nudge,
      SacStatusKind.validated => _IconEffect.draw,
      _ => _IconEffect.none,
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final style = widget.style;
    final title = widget.title;
    final onTap = widget.onTap;
    final message = widget.message;
    final stepLabel = widget.stepLabel;
    final semanticsHint = widget.semanticsHint;
    final semanticsLabel = widget.semanticsLabel;
    final reduceMotion = SacMotion.reduceMotionOf(context);

    return Semantics(
      container: true,
      button: onTap != null,
      hint: semanticsHint,
      label: semanticsLabel ??
          [
            title,
            if (message != null) message,
            if (stepLabel != null) stepLabel
          ].join('. '),
      excludeSemantics: true,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(color: c.border),
          boxShadow: [
            BoxShadow(
              color: c.shadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: c.surface,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          child: SacInkWell(
            onTap: onTap,
            pressedScale: SacMotion.panelPressScale,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration:
                          reduceMotion ? Duration.zero : SacMotion.standard,
                      switchInCurve: SacMotion.easeOut,
                      switchOutCurve: SacMotion.easeOut,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(
                            begin: SacMotion.enterScale,
                            end: 1,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      // Keyed by what the user reads, so a real change of
                      // state cross-fades and a plain rebuild does not.
                      child: Row(
                        key: ValueKey(_keyOf(widget)),
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: style.container,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusSM),
                            ),
                            alignment: Alignment.center,
                            child: _PanelIcon(
                              effect: reduceMotion ? _IconEffect.none : _effect,
                              child: HugeIcon(
                                icon: style.icon,
                                size: 22,
                                color: style.onContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: SacFontSize.titleLarge,
                                    fontWeight: FontWeight.w700,
                                    height: 1.25,
                                    color: c.text,
                                  ),
                                ),
                                if (message != null) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    message,
                                    style: TextStyle(
                                      fontSize: SacFontSize.bodyMedium,
                                      height: 1.4,
                                      color: c.textSecondary,
                                    ),
                                  ),
                                ],
                                if (stepLabel != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    stepLabel,
                                    style: TextStyle(
                                      fontSize: SacFontSize.bodySmall,
                                      fontWeight: FontWeight.w600,
                                      color: style.onContainer,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 8),
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowRight01,
                      size: 18,
                      color: c.textTertiary,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Plays the icon effect once, when it first builds: the "sent" icon nudges
/// 3 px up and right and back ([SacMotion.nudge]); the validated check is
/// revealed left to right like a stroke being drawn ([SacMotion.draw], after
/// 80 ms). Without an effect it is just the icon.
class _PanelIcon extends StatefulWidget {
  const _PanelIcon({required this.effect, required this.child});

  final _IconEffect effect;
  final Widget child;

  @override
  State<_PanelIcon> createState() => _PanelIconState();
}

class _PanelIconState extends State<_PanelIcon>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  static const _drawDelay = Duration(milliseconds: 80);

  @override
  void initState() {
    super.initState();
    switch (widget.effect) {
      case _IconEffect.none:
        break;
      case _IconEffect.nudge:
        _controller =
            AnimationController(vsync: this, duration: SacMotion.nudge)
              ..forward();
      case _IconEffect.draw:
        _controller = AnimationController(
          vsync: this,
          duration: SacMotion.draw + _drawDelay,
        )..forward();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return widget.child;
    return AnimatedBuilder(
      animation: controller,
      child: widget.child,
      builder: (context, child) {
        if (controller.isCompleted) return child!;
        if (widget.effect == _IconEffect.nudge) {
          // Out to (3, -3) at 40 % of the time, then back.
          final t = controller.value;
          final k = t < 0.4 ? t / 0.4 : 1 - (t - 0.4) / 0.6;
          final eased = SacMotion.easeOut.transform(k.clamp(0.0, 1.0));
          return Transform.translate(
            offset: Offset(3 * eased, -3 * eased),
            child: child,
          );
        }
        final start = _drawDelay.inMilliseconds /
            (SacMotion.draw + _drawDelay).inMilliseconds;
        final t = ((controller.value - start) / (1 - start)).clamp(0.0, 1.0);
        return ClipRect(
          clipper: _WipeClipper(SacMotion.easeOut.transform(t)),
          child: child,
        );
      },
    );
  }
}

/// Keeps the left [fraction] of the box.
class _WipeClipper extends CustomClipper<Rect> {
  const _WipeClipper(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(_WipeClipper oldClipper) => oldClipper.fraction != fraction;
}
