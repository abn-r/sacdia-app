import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_tweened_bar.dart';

import 'sac_badge_tint.dart';

enum SacBadgeMetaKind { none, obtained, progress, warning }

/// The line at the bottom of a [SacBadgeCard]: what state the badge is in.
@immutable
class SacBadgeMeta {
  /// Nothing to say (not started, secret).
  const SacBadgeMeta.none()
      : kind = SacBadgeMetaKind.none,
        label = null,
        fraction = 0;

  /// Check mark and [label] (a short date, "Obtained").
  const SacBadgeMeta.obtained(String this.label)
      : kind = SacBadgeMetaKind.obtained,
        fraction = 1;

  /// Thin bar in the app accent and a count such as "6 de 10".
  const SacBadgeMeta.progress({
    required this.fraction,
    required String this.label,
  }) : kind = SacBadgeMetaKind.progress;

  /// Text in the warning colour ("No longer valid").
  const SacBadgeMeta.warning(String this.label)
      : kind = SacBadgeMetaKind.warning,
        fraction = 0;

  final SacBadgeMetaKind kind;
  final String? label;

  /// Bar value 0..1 (only for [SacBadgeMetaKind.progress]).
  final double fraction;
}

/// One card of the badge grids (achievements and masteries): paper surface,
/// 1 px border, the art, the full name (up to three lines) and a meta line.
///
/// Every card of a grid has the same height ([heightFor]), so rows align at
/// any text scale. Pressing scales the card ([SacPressable]).
///
/// When [tone] changes from grey/dimmed to colour while the card is on
/// screen the art animates: colour comes in with a small overshoot, an accent
/// halo fades out and the meta line cross-fades. Reduced Motion only
/// cross-fades.
class SacBadgeCard extends StatefulWidget {
  const SacBadgeCard({
    super.key,
    required this.name,
    required this.art,
    required this.tone,
    this.meta = const SacBadgeMeta.none(),
    this.nameEmphasized = false,
    this.onTap,
    this.artHeight = defaultArtHeight,
  });

  /// Already translated, shown in full.
  final String name;

  /// The badge as it looks in full colour. [tone] tints it; never reshape it.
  final Widget art;
  final SacBadgeTone tone;
  final SacBadgeMeta meta;

  /// Obtained cards use the strong name; the rest the secondary one.
  final bool nameEmphasized;
  final VoidCallback? onTap;

  /// Height of the art slot; the art is centered and keeps its own shape.
  final double artHeight;

  static const double defaultArtHeight = 60;

  static const double _padTop = 12;
  static const double _padHorizontal = 4;
  static const double _padBottom = 10;
  static const double _artGap = 8;
  static const double _metaGap = 6;
  static const double _barHeight = 4;
  static const double _barGap = 5;
  static const double _nameLineHeight = 1.2;
  static const double _metaLineHeight = 1.2;
  static const int nameMaxLines = 3;
  static const double _border = 1;

  static double _nameHeight(TextScaler scaler) =>
      scaler.scale(SacFontSize.bodySmall) * _nameLineHeight * nameMaxLines;

  static double _metaTextHeight(TextScaler scaler) =>
      scaler.scale(SacFontSize.labelSmall) * _metaLineHeight;

  /// The height every card needs at [scaler]: three name lines plus the
  /// meta slot, so nothing overflows however large the text is.
  static double heightFor(
    TextScaler scaler, {
    double artHeight = defaultArtHeight,
  }) {
    return (_padTop +
            artHeight +
            _artGap +
            _nameHeight(scaler) +
            _metaGap +
            _barHeight +
            _barGap +
            _metaTextHeight(scaler) +
            _padBottom +
            _border * 2)
        .ceilToDouble();
  }

  @override
  State<SacBadgeCard> createState() => _SacBadgeCardState();
}

class _SacBadgeCardState extends State<SacBadgeCard>
    with TickerProviderStateMixin {
  AnimationController? _reveal;
  AnimationController? _halo;
  SacBadgeTone _from = SacBadgeTone.color;
  bool _reduce = false;

  @override
  void didUpdateWidget(SacBadgeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final becameColor = oldWidget.tone != SacBadgeTone.color &&
        widget.tone == SacBadgeTone.color;
    if (becameColor) {
      _playReveal(oldWidget.tone);
    } else if (widget.tone != SacBadgeTone.color) {
      _reveal?.stop();
      _halo?.stop();
    }
  }

  void _playReveal(SacBadgeTone from) {
    _from = from;
    _reduce = SacMotion.reduceMotionOf(context);
    final reveal = (_reveal ??= AnimationController(vsync: this))
      ..duration = _reduce ? SacMotion.reducedFade : SacMotion.unlock;
    reveal.forward(from: 0);
    if (!_reduce) {
      final halo = _halo ??= AnimationController(vsync: this);
      halo.duration = SacMotion.halo;
      halo.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _reveal?.dispose();
    _halo?.dispose();
    super.dispose();
  }

  static final Animatable<double> _overshoot = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(begin: 1, end: SacMotion.unlockOvershoot)
          .chain(CurveTween(curve: SacMotion.easeOut)),
      weight: 60,
    ),
    TweenSequenceItem(
      tween: Tween<double>(begin: SacMotion.unlockOvershoot, end: 1)
          .chain(CurveTween(curve: SacMotion.easeInOut)),
      weight: 40,
    ),
  ]);

  Widget _artSlot(BuildContext context) {
    final reveal = _reveal;
    final halo = _halo;
    final accent = SacAccent.of(context).color;
    final listenables = <Listenable>[
      if (reveal != null) reveal,
      if (halo != null) halo,
    ];

    return AnimatedBuilder(
      animation: Listenable.merge(listenables),
      builder: (context, _) {
        final revealing = reveal != null &&
            reveal.status == AnimationStatus.forward &&
            widget.tone == SacBadgeTone.color;
        var gray = widget.tone.gray;
        var opacity = widget.tone.opacity;
        var scale = 1.0;
        if (revealing) {
          final t = reveal.value;
          final eased = _reduce ? t : SacMotion.easeOut.transform(t);
          gray = _from.gray * (1 - eased);
          opacity = _from.opacity + (1 - _from.opacity) * eased;
          if (!_reduce) scale = _overshoot.transform(t);
        }

        Widget art =
            SacBadgeTint(gray: gray, opacity: opacity, child: widget.art);
        if (scale != 1) art = Transform.scale(scale: scale, child: art);

        final haloValue = halo != null && halo.isAnimating ? halo.value : null;
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (haloValue != null)
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(
                          alpha: 0.32 *
                              (1 - SacMotion.easeOut.transform(haloValue)),
                        ),
                        blurRadius: 8,
                        spreadRadius:
                            16 * SacMotion.easeOut.transform(haloValue),
                      ),
                    ],
                  ),
                  child: SizedBox.square(dimension: widget.artHeight * 0.8),
                ),
              ),
            art,
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final meta = widget.meta;
    final label =
        meta.label == null ? widget.name : '${widget.name}, ${meta.label}';

    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: c.paper,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: c.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          SacBadgeCard._padHorizontal,
          SacBadgeCard._padTop,
          SacBadgeCard._padHorizontal,
          SacBadgeCard._padBottom,
        ),
        child: Column(
          children: [
            SizedBox(
              height: widget.artHeight,
              width: double.infinity,
              child: Center(child: _artSlot(context)),
            ),
            const SizedBox(height: SacBadgeCard._artGap),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: Text(
                  widget.name,
                  textAlign: TextAlign.center,
                  maxLines: SacBadgeCard.nameMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: SacFontSize.bodySmall,
                    fontWeight: widget.nameEmphasized
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: widget.nameEmphasized ? c.text : c.textSecondary,
                    height: SacBadgeCard._nameLineHeight,
                  ),
                ),
              ),
            ),
            const SizedBox(height: SacBadgeCard._metaGap),
            _MetaSlot(meta: meta),
          ],
        ),
      ),
    );

    return Semantics(
      container: true,
      button: widget.onTap != null,
      label: label,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: SacPressable(
        onTap: widget.onTap,
        semanticButton: false,
        child: card,
      ),
    );
  }
}

/// Fixed-height slot at the bottom of the card; its content sits at the
/// bottom and cross-fades when the kind of meta changes.
class _MetaSlot extends StatelessWidget {
  const _MetaSlot({required this.meta});

  final SacBadgeMeta meta;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final height = SacBadgeCard._barHeight +
        SacBadgeCard._barGap +
        SacBadgeCard._metaTextHeight(scaler);
    final reduce = SacMotion.reduceMotionOf(context);

    return SizedBox(
      height: height,
      width: double.infinity,
      child: AnimatedSwitcher(
        duration: reduce ? SacMotion.reducedFade : SacMotion.standard,
        switchInCurve: SacMotion.easeOut,
        switchOutCurve: SacMotion.easeOut,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.bottomCenter,
          children: [...previous, if (current != null) current],
        ),
        child: KeyedSubtree(
          key: ValueKey(meta.kind),
          child: _MetaContent(meta: meta),
        ),
      ),
    );
  }
}

class _MetaContent extends StatelessWidget {
  const _MetaContent({required this.meta});

  final SacBadgeMeta meta;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final label = meta.label;
    if (meta.kind == SacBadgeMetaKind.none || label == null) {
      return const SizedBox.shrink();
    }

    TextStyle style(Color color) => TextStyle(
          fontSize: SacFontSize.labelSmall,
          fontWeight: FontWeight.w600,
          height: SacBadgeCard._metaLineHeight,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        );

    switch (meta.kind) {
      case SacBadgeMetaKind.obtained:
        return Align(
          alignment: Alignment.bottomCenter,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedTick02,
                  size: 12,
                  color: c.onSuccessContainer,
                ),
                const SizedBox(width: 3),
                Text(label, style: style(c.onSuccessContainer)),
              ],
            ),
          ),
        );
      case SacBadgeMetaKind.warning:
        return Align(
          alignment: Alignment.bottomCenter,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, style: style(c.onWarningContainer)),
          ),
        );
      case SacBadgeMetaKind.progress:
        return Align(
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FractionallySizedBox(
                widthFactor: 0.76,
                child: SacTweenedBar(
                  value: meta.fraction,
                  color: SacAccent.of(context).color,
                  backgroundColor: c.border,
                  minHeight: SacBadgeCard._barHeight,
                  borderRadius: AppTheme.radiusHairline,
                ),
              ),
              const SizedBox(height: SacBadgeCard._barGap),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label, style: style(c.textSecondary)),
              ),
            ],
          ),
        );
      case SacBadgeMetaKind.none:
        return const SizedBox.shrink();
    }
  }
}
