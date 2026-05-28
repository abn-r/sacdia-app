import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

class MonthlyReportEntrance extends StatefulWidget {
  final Widget child;
  final int index;
  final double offsetY;

  const MonthlyReportEntrance({
    super.key,
    required this.child,
    this.index = 0,
    this.offsetY = 16,
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
        Timer(Duration(milliseconds: (widget.index * 42).clamp(0, 260)), () {
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
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: AnimatedScale(
        scale: _visible ? 1 : 0.985,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class MonthlyReportSkeletonList extends StatelessWidget {
  const MonthlyReportSkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return const MonthlyReportEntrance(
            child: _SkeletonBlock(height: 152, radius: 24, lines: 3),
          );
        }

        return MonthlyReportEntrance(
          index: index,
          child: const _SkeletonReportTile(),
        );
      },
    );
  }
}

class MonthlyReportDetailSkeleton extends StatelessWidget {
  const MonthlyReportDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: const [
        MonthlyReportEntrance(
          child: _SkeletonBlock(height: 94, radius: 22, lines: 2),
        ),
        SizedBox(height: 16),
        MonthlyReportEntrance(
          index: 1,
          child: _SkeletonBlock(height: 54, radius: 16, lines: 1),
        ),
        SizedBox(height: 18),
        MonthlyReportEntrance(
          index: 2,
          child: _SkeletonKpiGrid(),
        ),
        SizedBox(height: 18),
        MonthlyReportEntrance(
          index: 3,
          child: _SkeletonBlock(height: 174, radius: 18, lines: 4),
        ),
        SizedBox(height: 14),
        MonthlyReportEntrance(
          index: 4,
          child: _SkeletonBlock(height: 148, radius: 18, lines: 3),
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

class _SkeletonReportTile extends StatelessWidget {
  const _SkeletonReportTile();

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          MonthlyReportLoadingPulse(
            width: 52,
            height: 52,
            borderRadius: BorderRadius.circular(16),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MonthlyReportLoadingPulse(
                  width: 140,
                  height: 16,
                  borderRadius: BorderRadius.circular(999),
                ),
                const SizedBox(height: 8),
                MonthlyReportLoadingPulse(
                  width: 210,
                  height: 11,
                  borderRadius: BorderRadius.circular(999),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          MonthlyReportLoadingPulse(
            width: 52,
            height: 24,
            borderRadius: BorderRadius.circular(999),
          ),
        ],
      ),
    );
  }
}

class _SkeletonKpiGrid extends StatelessWidget {
  const _SkeletonKpiGrid();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        Row(
          children: [
            Expanded(child: _SkeletonBlock(height: 104, radius: 16)),
            SizedBox(width: 12),
            Expanded(child: _SkeletonBlock(height: 104, radius: 16)),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _SkeletonBlock(height: 104, radius: 16)),
            SizedBox(width: 12),
            Expanded(child: _SkeletonBlock(height: 104, radius: 16)),
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
