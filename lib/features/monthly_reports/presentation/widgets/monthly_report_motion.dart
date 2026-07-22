import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

/// Short stagger entrance — keep under ~200ms total for frequent screens.
class MonthlyReportEntrance extends StatefulWidget {
  final Widget child;
  final int index;
  final double offsetY;

  const MonthlyReportEntrance({
    super.key,
    required this.child,
    this.index = 0,
    this.offsetY = 8,
  });

  @override
  State<MonthlyReportEntrance> createState() => _MonthlyReportEntranceState();
}

class _MonthlyReportEntranceState extends State<MonthlyReportEntrance> {
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _timer =
        Timer(Duration(milliseconds: (widget.index * 36).clamp(0, 144)), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion(context)) return widget.child;

    return AnimatedSlide(
      offset: _visible ? Offset.zero : Offset(0, widget.offsetY / 100),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Press feedback: scale on touch-down (Apple response + Emil button craft).
class MonthlyReportPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final double pressedScale;

  const MonthlyReportPressable({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
    this.pressedScale = 0.97,
  });

  @override
  State<MonthlyReportPressable> createState() => _MonthlyReportPressableState();
}

class _MonthlyReportPressableState extends State<MonthlyReportPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || widget.onTap == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = _reduceMotion(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: (!reduce && _pressed) ? widget.pressedScale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Frosted sticky chrome for bottom CTAs / app bars.
class MonthlyReportFrostBar extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const MonthlyReportFrostBar({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 10, 20, 16),
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final reduceTransparency =
        MediaQuery.maybeOf(context)?.highContrast == true;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: reduceTransparency ? 0 : 18,
          sigmaY: reduceTransparency ? 0 : 18,
        ),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: reduceTransparency ? 1 : 0.78),
            border: Border(
              top: BorderSide(color: c.border.withValues(alpha: 0.55)),
            ),
          ),
          child: SafeArea(top: false, child: child),
        ),
      ),
    );
  }
}

class MonthlyReportSkeletonList extends StatelessWidget {
  const MonthlyReportSkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: const [
        MonthlyReportEntrance(
          child: _SkeletonBlock(height: 72, radius: 18, lines: 1),
        ),
        SizedBox(height: 22),
        MonthlyReportEntrance(
          index: 1,
          child: _SkeletonBlock(height: 14, radius: 8, lines: 1),
        ),
        SizedBox(height: 12),
        MonthlyReportEntrance(
          index: 2,
          child: _SkeletonBlock(height: 200, radius: 18, lines: 4),
        ),
      ],
    );
  }
}

class MonthlyReportDetailSkeleton extends StatelessWidget {
  const MonthlyReportDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: const [
        MonthlyReportEntrance(
          child: _SkeletonBlock(height: 120, radius: 22, lines: 2),
        ),
        SizedBox(height: 18),
        MonthlyReportEntrance(
          index: 1,
          child: _SkeletonKpiGrid(),
        ),
        SizedBox(height: 18),
        MonthlyReportEntrance(
          index: 2,
          child: _SkeletonBlock(height: 64, radius: 16, lines: 1),
        ),
        SizedBox(height: 10),
        MonthlyReportEntrance(
          index: 3,
          child: _SkeletonBlock(height: 64, radius: 16, lines: 1),
        ),
      ],
    );
  }
}

class MonthlyReportLoadingPulse extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const MonthlyReportLoadingPulse({
    super.key,
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: c.border.withValues(alpha: 0.42),
        borderRadius: borderRadius,
      ),
    );
  }
}

class _SkeletonKpiGrid extends StatelessWidget {
  const _SkeletonKpiGrid();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Row(
          children: [
            Expanded(child: _SkeletonBlock(height: 88, radius: 16)),
            SizedBox(width: 12),
            Expanded(child: _SkeletonBlock(height: 88, radius: 16)),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _SkeletonBlock(height: 88, radius: 16)),
            SizedBox(width: 12),
            Expanded(child: _SkeletonBlock(height: 88, radius: 16)),
          ],
        ),
      ],
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  final double height;
  final double radius;
  final int lines;

  const _SkeletonBlock({
    required this.height,
    required this.radius,
    this.lines = 2,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: c.border.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MonthlyReportLoadingPulse(
              width: 120,
              height: 14,
              borderRadius: BorderRadius.circular(999),
            ),
            if (lines > 1) ...[
              const SizedBox(height: 12),
              MonthlyReportLoadingPulse(
                width: double.infinity,
                height: 12,
                borderRadius: BorderRadius.circular(999),
              ),
            ],
            if (lines > 2) ...[
              const SizedBox(height: 8),
              MonthlyReportLoadingPulse(
                width: 180,
                height: 12,
                borderRadius: BorderRadius.circular(999),
              ),
            ],
            if (lines > 3) ...[
              const SizedBox(height: 8),
              MonthlyReportLoadingPulse(
                width: 230,
                height: 12,
                borderRadius: BorderRadius.circular(999),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

bool _reduceMotion(BuildContext context) {
  final media = MediaQuery.maybeOf(context);
  return media?.disableAnimations == true ||
      media?.accessibleNavigation == true;
}
