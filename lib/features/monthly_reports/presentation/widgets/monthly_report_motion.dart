import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';

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
    _timer = Timer(
      Duration(milliseconds: (widget.index * 40).clamp(0, 160)),
      () {
        if (mounted) setState(() => _visible = true);
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (SacMotion.reduceMotionOf(context)) return widget.child;

    return AnimatedSlide(
      offset: _visible ? Offset.zero : Offset(0, widget.offsetY / 100),
      duration: SacMotion.standard,
      curve: SacMotion.easeOut,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: SacMotion.standard,
        curve: SacMotion.easeOut,
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

/// Esqueleto de la lista: un grupo de filas bajo su etiqueta.
class MonthlyReportSkeletonList extends StatelessWidget {
  const MonthlyReportSkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    return SacShimmer(
      child: ExcludeSemantics(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: SacTopBar.paddingBelowBar(context, EdgeInsets.zero),
          children: const [
            _SkeletonGroup(rows: 1),
            _SkeletonGroup(rows: 4),
          ],
        ),
      ),
    );
  }
}

/// Esqueleto del detalle: panel de estado, grupo de filas y otro grupo.
class MonthlyReportDetailSkeleton extends StatelessWidget {
  const MonthlyReportDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SacShimmer(
      child: ExcludeSemantics(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: SacTopBar.paddingBelowBar(
              context, const EdgeInsets.fromLTRB(20, 12, 20, 0)),
          children: const [
            SacSkeletonBox(height: 88, radius: AppTheme.radiusMD),
            _SkeletonGroup(rows: 4, horizontalInset: 0),
            _SkeletonGroup(rows: 3, horizontalInset: 0),
          ],
        ),
      ),
    );
  }
}

class _SkeletonGroup extends StatelessWidget {
  final int rows;
  final double horizontalInset;

  const _SkeletonGroup({required this.rows, this.horizontalInset = 20});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalInset, 24, horizontalInset, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SacSkeletonBox(width: 90, height: 11),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              border: Border.all(color: c.border),
            ),
            child: Column(
              children: [
                for (var i = 0; i < rows; i++) ...[
                  if (i > 0) Divider(height: 1, thickness: 1, color: c.divider),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    child: Row(
                      children: [
                        SacSkeletonBox(width: 32, height: 32, radius: 16),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SacSkeletonBox(width: 130, height: 14),
                              SizedBox(height: 8),
                              SacSkeletonBox(width: 90, height: 11),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
