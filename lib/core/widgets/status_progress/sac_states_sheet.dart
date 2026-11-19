import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../animations/motion_tokens.dart';
import '../../theme/app_theme.dart';
import '../../theme/sac_accent.dart';
import '../../theme/sac_colors.dart';
import '../sac_sheet.dart';

/// Where a state stands in the path of an item.
enum SacStateKind { done, current, rejected, pending }

/// One state in the list of [SacStatesSheet].
class SacStateStep {
  const SacStateStep({required this.kind, required this.title, this.detail});

  final SacStateKind kind;

  /// Already translated.
  final String title;

  /// A date or one line of context, already translated.
  final String? detail;
}

/// Already translated words for a screen reader, one per [SacStateKind].
class SacStateKindLabels {
  const SacStateKindLabels({
    required this.done,
    required this.current,
    required this.rejected,
    required this.pending,
  });

  final String done;
  final String current;
  final String rejected;
  final String pending;

  String of(SacStateKind kind) => switch (kind) {
        SacStateKind.done => done,
        SacStateKind.current => current,
        SacStateKind.rejected => rejected,
        SacStateKind.pending => pending,
      };
}

/// Opens [SacStatesSheet] as a bottom sheet.
Future<void> showSacStatesSheet(
  BuildContext context, {
  required String title,
  required List<SacStateStep> steps,
  required SacStateKindLabels kindLabels,
  String? subtitle,
  SacStateStep? detour,
}) {
  return showSacSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => SacStatesSheet(
      title: title,
      subtitle: subtitle,
      steps: steps,
      kindLabels: kindLabels,
      detour: detour,
    ),
  );
}

/// Every state of an item, in order, joined by a line: a check for the ones
/// done (with their date), a filled dot for the current one, a cross for a
/// rejected one and a hollow dot for the ones still to come.
///
/// It lives in a sheet on purpose: the screen shows only the current state
/// and this list is one tap away.
class SacStatesSheet extends StatefulWidget {
  const SacStatesSheet({
    super.key,
    required this.title,
    required this.steps,
    required this.kindLabels,
    this.subtitle,
    this.detour,
  });

  final String title;
  final String? subtitle;
  final List<SacStateStep> steps;
  final SacStateKindLabels kindLabels;

  /// A way out of the path (for example "To fix"), set apart under a
  /// divider and not joined to the steps by the line. Use
  /// [SacStateKind.rejected] when the item is in it right now and
  /// [SacStateKind.pending] when it is only explained.
  final SacStateStep? detour;

  @override
  State<SacStatesSheet> createState() => _SacStatesSheetState();
}

/// Rows enter one after another (fade + rise 8 px) and the current state dot
/// emits a single ring. One controller, run once and never looped; with
/// Reduced Motion it is never started.
class _SacStatesSheetState extends State<SacStatesSheet>
    with SingleTickerProviderStateMixin {
  static const _rowDelay = Duration(milliseconds: 120);
  static const _rowDuration = Duration(milliseconds: 220);
  static const _ringDelay = Duration(milliseconds: 360);
  static const _rise = 8.0;

  late final AnimationController _controller;
  bool _started = false;

  int get _rows => widget.steps.length + (widget.detour != null ? 1 : 0);

  Duration get _total {
    final rowsEnd = _rowDelay +
        SacMotion.stagger * (_rows > 0 ? _rows - 1 : 0) +
        _rowDuration;
    final ringEnd = _ringDelay + SacMotion.ring;
    return rowsEnd > ringEnd ? rowsEnd : ringEnd;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _total);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (SacMotion.reduceMotionOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Interval _interval(Duration start, Duration length) {
    final total = _total.inMilliseconds;
    return Interval(
      start.inMilliseconds / total,
      (start + length).inMilliseconds / total,
      curve: SacMotion.easeOut,
    );
  }

  Widget _entering(int index, Widget child) {
    final curve = _interval(
      _rowDelay + SacMotion.stagger * index,
      _rowDuration,
    );
    return AnimatedBuilder(
      animation: _controller,
      child: child,
      builder: (context, child) {
        final t = curve.transform(_controller.value);
        if (t >= 1) return child!;
        return Opacity(
          opacity: t,
          alwaysIncludeSemantics: true,
          child: Transform.translate(
            offset: Offset(0, _rise * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final subtitle = widget.subtitle;
    final steps = widget.steps;
    final detour = widget.detour;
    final kindLabels = widget.kindLabels;
    final title = widget.title;
    final ring = _interval(_ringDelay, SacMotion.ring);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLG),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SacSheetGrabber(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: SacFontSize.titleLarge,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: SacFontSize.bodyMedium,
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  key: const ValueKey('states-sheet-steps'),
                  children: [
                    for (var i = 0; i < steps.length; i++)
                      _entering(
                        i,
                        _StepRow(
                          step: steps[i],
                          kindLabels: kindLabels,
                          isLast: i == steps.length - 1,
                          ring: ring.transform,
                          ringListenable: _controller,
                        ),
                      ),
                    if (detour != null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Divider(
                          key: const ValueKey('states-sheet-detour-divider'),
                          height: 1,
                          color: c.divider,
                        ),
                      ),
                      _entering(
                        steps.length,
                        _StepRow(
                          key: const ValueKey('states-sheet-detour'),
                          step: detour,
                          kindLabels: kindLabels,
                          isLast: true,
                          isDetour: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    super.key,
    required this.step,
    required this.kindLabels,
    required this.isLast,
    this.isDetour = false,
    this.ring,
    this.ringListenable,
  });

  final SacStateStep step;
  final SacStateKindLabels kindLabels;
  final bool isLast;
  final bool isDetour;

  /// Maps the sheet controller value to the ring progress (0..1); only the
  /// current state draws it.
  final double Function(double)? ring;
  final Animation<double>? ringListenable;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final pending = step.kind == SacStateKind.pending;
    final detail = step.detail;
    final detailColor = step.kind == SacStateKind.rejected
        ? c.onErrorContainer
        : c.textSecondary;

    return Semantics(
      container: true,
      label: [
        step.title,
        if (detail != null && detail.isNotEmpty) detail,
        kindLabels.of(step.kind),
      ].join('. '),
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 24,
              child: Column(
                children: [
                  _Dot(
                    kind: step.kind,
                    isDetour: isDetour,
                    ring: ring,
                    ringListenable: ringListenable,
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: step.kind == SacStateKind.done
                            ? c.success.withValues(alpha: 0.45)
                            : c.divider,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 2, bottom: isLast ? 0 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: TextStyle(
                        fontSize: SacFontSize.titleMedium,
                        fontWeight: pending ? FontWeight.w500 : FontWeight.w600,
                        height: 1.25,
                        color: pending ? c.textSecondary : c.text,
                      ),
                    ),
                    if (detail != null && detail.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          detail,
                          style: TextStyle(
                            fontSize: SacFontSize.bodySmall,
                            height: 1.35,
                            color: detailColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.kind,
    this.isDetour = false,
    this.ring,
    this.ringListenable,
  });

  final SacStateKind kind;
  final bool isDetour;
  final double Function(double)? ring;
  final Animation<double>? ringListenable;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    if (isDetour) {
      final active = kind == SacStateKind.rejected;
      return _circle(
        background: active ? c.errorContainer : c.surfaceVariant,
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedAlertCircle,
          size: 14,
          color: active ? c.onErrorContainer : c.textSecondary,
        ),
      );
    }
    return switch (kind) {
      SacStateKind.done => _circle(
          background: c.successContainer,
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedTick02,
            size: 14,
            color: c.onSuccessContainer,
          ),
        ),
      SacStateKind.current => _withRing(
          accent.color,
          _circle(
            background: accent.color,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: accent.onColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      SacStateKind.rejected => _circle(
          background: c.errorContainer,
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedCancel01,
            size: 13,
            color: c.onErrorContainer,
          ),
        ),
      SacStateKind.pending => Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: c.surface,
            shape: BoxShape.circle,
            border: Border.all(color: c.border, width: 2),
          ),
        ),
    };
  }

  /// One ring around the dot: scale 1 -> 1.7, opacity .45 -> 0. Nothing is
  /// painted before it starts or after it ends.
  Widget _withRing(Color color, Widget dot) {
    final ring = this.ring;
    final listenable = ringListenable;
    if (ring == null || listenable == null) return dot;
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: AnimatedBuilder(
                  animation: listenable,
                  builder: (context, _) {
                    final t = ring(listenable.value);
                    if (t <= 0 || t >= 1) return const SizedBox.shrink();
                    return Opacity(
                      opacity: 0.45 * (1 - t),
                      child: Transform.scale(
                        scale: 1 + 0.7 * t,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: color, width: 2),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          dot,
        ],
      ),
    );
  }

  Widget _circle({required Color background, required Widget child}) =>
      Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: child,
      );
}
