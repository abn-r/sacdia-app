import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sacdia_app/core/animations/animated_counter.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_progress_bar.dart';

/// Bar and big percentage of the current class card.
///
/// At 100 % it celebrates once per appearance, after the counter has
/// finished: the number pulses (1 -> 1.07 -> 1, [SacMotion.pulse]), the bar
/// turns success green and a single sheen crosses it ([SacMotion.ring]).
/// It never loops. Reduced Motion only turns the bar green.
class ClassProgressLine extends StatefulWidget {
  const ClassProgressLine({
    super.key,
    required this.percent,
    required this.progress,
  });

  /// Whole percent shown by the counter.
  final int percent;

  /// 0..1, drives the bar.
  final double progress;

  @override
  State<ClassProgressLine> createState() => _ClassProgressLineState();
}

class _ClassProgressLineState extends State<ClassProgressLine>
    with SingleTickerProviderStateMixin {
  static const _sheenDelay = Duration(milliseconds: 200);

  late final AnimationController _celebrate;
  late final Animation<double> _pulse;
  late final Animation<double> _sheen;
  Timer? _timer;
  bool _done = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    final total = _sheenDelay + SacMotion.ring;
    _celebrate = AnimationController(vsync: this, duration: total);
    _pulse = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.07)
            .chain(CurveTween(curve: SacMotion.easeOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.07, end: 1.0)
            .chain(CurveTween(curve: SacMotion.easeOut)),
        weight: 55,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _celebrate,
        curve: Interval(
          0,
          SacMotion.pulse.inMilliseconds / total.inMilliseconds,
        ),
      ),
    );
    _sheen = CurvedAnimation(
      parent: _celebrate,
      curve: Interval(
        _sheenDelay.inMilliseconds / total.inMilliseconds,
        1,
        curve: SacMotion.easeInOut,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.percent >= 100) {
      // Counter waits SacMotion.modal, then counts for SacMotion.reveal.
      _arm(SacMotion.modal + SacMotion.reveal);
    }
  }

  @override
  void didUpdateWidget(ClassProgressLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.percent < 100 && widget.percent >= 100) {
      _arm(SacMotion.reveal);
    } else if (widget.percent < 100) {
      _timer?.cancel();
      if (_done) setState(() => _done = false);
    }
  }

  void _arm(Duration afterCounter) {
    _timer?.cancel();
    if (SacMotion.reduceMotionOf(context)) {
      _done = true;
      return;
    }
    _timer = Timer(afterCounter, () {
      if (!mounted) return;
      setState(() => _done = true);
      _celebrate.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _celebrate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context).color;
    final reduce = SacMotion.reduceMotionOf(context);
    final barColor = _done ? c.success : accent;

    return Row(
      children: [
        Expanded(
          child: Stack(
            children: [
              TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: barColor),
                duration: reduce ? Duration.zero : SacMotion.standard,
                curve: SacMotion.easeOut,
                builder: (context, color, _) => SacProgressBar(
                  progress: widget.progress,
                  color: color ?? barColor,
                  height: 6,
                  showShimmer: false,
                  fillDuration: SacMotion.reveal,
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    child: AnimatedBuilder(
                      animation: _sheen,
                      builder: (context, _) {
                        final t = _sheen.value;
                        if (t <= 0 || t >= 1) return const SizedBox.shrink();
                        return FractionalTranslation(
                          translation: Offset(-1 + 2 * t, 0),
                          child: FractionallySizedBox(
                            widthFactor: 0.4,
                            alignment: Alignment.centerLeft,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0),
                                    Colors.white.withValues(alpha: 0.7),
                                    Colors.white.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ScaleTransition(
          scale: _pulse,
          alignment: Alignment.centerRight,
          child: AnimatedCounter(
            value: widget.percent,
            suffix: '%',
            duration: SacMotion.reveal,
            style: TextStyle(
              fontSize: SacFontSize.displaySmall,
              fontWeight: FontWeight.w800,
              height: 1,
              color: c.text,
            ),
          ),
        ),
      ],
    );
  }
}
