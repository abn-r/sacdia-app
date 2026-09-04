import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/features/master_honors/domain/entities/master_honor_roadmap.dart';
import 'package:sacdia_app/features/master_honors/presentation/widgets/master_honor_detail_presentation.dart';
import 'package:sacdia_app/features/master_honors/presentation/widgets/master_honor_detail_sheet.dart';
import 'package:sacdia_app/features/master_honors/presentation/widgets/master_honor_logo.dart';

export 'master_honor_detail_presentation.dart'
    show MasterHonorGridVisual, masterHonorGridVisual;
export 'master_honor_detail_sheet.dart' show showMasterHonorDetailSheet;
export 'master_honor_logo.dart';

const double _kLogoSize = 72;
const double _kCounterSlot = 24;
const double _kProgressSlot = 9;

class MasterHonorRoadmapGrid extends StatelessWidget {
  const MasterHonorRoadmapGrid({
    super.key,
    required this.items,
    this.padding = const EdgeInsets.all(16),
    this.physics,
    this.shrinkWrap = false,
  });

  final List<MasterHonorRoadmap> items;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics,
      padding: padding,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.62,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final delayMs = index.clamp(0, 11) * SacMotion.stagger.inMilliseconds;
        return MasterHonorRoadmapGridItem(
          item: items[index],
          animationDelay: Duration(milliseconds: delayMs),
        );
      },
    );
  }
}

class MasterHonorRoadmapGridItem extends StatefulWidget {
  const MasterHonorRoadmapGridItem({
    super.key,
    required this.item,
    this.animationDelay = Duration.zero,
  });

  final MasterHonorRoadmap item;
  final Duration animationDelay;

  @override
  State<MasterHonorRoadmapGridItem> createState() =>
      _MasterHonorRoadmapGridItemState();
}

class _MasterHonorRoadmapGridItemState extends State<MasterHonorRoadmapGridItem>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _enterController;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  Timer? _delayedStart;
  bool? _reduceMotion;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: SacMotion.standard,
    );
    _fade = CurvedAnimation(parent: _enterController, curve: SacMotion.easeOut);
    _scale = Tween<double>(begin: SacMotion.enterScale, end: 1).animate(
      CurvedAnimation(parent: _enterController, curve: SacMotion.easeOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = SacMotion.reduceMotionOf(context);
    if (_reduceMotion == reduceMotion) return;

    final firstRead = _reduceMotion == null;
    _reduceMotion = reduceMotion;

    if (reduceMotion) {
      _delayedStart?.cancel();
      _enterController.value = 1;
    } else if (firstRead) {
      _delayedStart = Timer(widget.animationDelay, () {
        if (mounted && _reduceMotion == false) _enterController.forward();
      });
    }
  }

  @override
  void dispose() {
    _delayedStart?.cancel();
    _enterController.dispose();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final visual = masterHonorGridVisual(item);
    final progress = item.progressPercent.clamp(0, 100) / 100;
    final accent = switch (visual) {
      MasterHonorGridVisual.awarded => AppColors.secondary,
      MasterHonorGridVisual.inProgress => AppColors.accent,
      MasterHonorGridVisual.inactive => AppColors.pendingDark,
      MasterHonorGridVisual.locked => context.sac.textTertiary,
    };
    final c = context.sac;
    final reduce = _reduceMotion ?? SacMotion.reduceMotionOf(context);
    final isMuted = visual == MasterHonorGridVisual.locked ||
        visual == MasterHonorGridVisual.inactive;
    final showCounter = visual == MasterHonorGridVisual.inProgress ||
        visual == MasterHonorGridVisual.awarded;
    final showBar = visual == MasterHonorGridVisual.inProgress;
    final nameColor =
        visual == MasterHonorGridVisual.awarded ? c.text : c.textSecondary;
    final nameWeight = visual == MasterHonorGridVisual.awarded
        ? FontWeight.w600
        : FontWeight.w500;

    final surfaceColor = switch (visual) {
      MasterHonorGridVisual.locked => c.surfaceVariant.withValues(alpha: 0.55),
      MasterHonorGridVisual.inactive => c.surfaceVariant.withValues(alpha: 0.7),
      _ => c.surface,
    };
    final borderColor = switch (visual) {
      MasterHonorGridVisual.awarded =>
        AppColors.secondary.withValues(alpha: 0.45),
      MasterHonorGridVisual.inProgress => c.border.withValues(alpha: 0.85),
      _ => c.border.withValues(alpha: 0.45),
    };

    final statusLabel = switch (visual) {
      MasterHonorGridVisual.awarded =>
        item.displayStatusLabel ?? 'Maestría obtenida',
      MasterHonorGridVisual.inactive => item.displayStatusLabel ?? 'No vigente',
      MasterHonorGridVisual.inProgress => 'Maestría en progreso',
      MasterHonorGridVisual.locked => 'Maestría sin avance',
    };

    Widget card = Semantics(
      button: true,
      label: '${item.name}, $statusLabel, ${item.progressPercent}% completado',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: () => showMasterHonorDetailSheet(context, item),
        child: AnimatedScale(
          scale: (!reduce && _pressed) ? SacMotion.pressScale : 1,
          duration: SacMotion.press,
          curve: SacMotion.easeOut,
          child: AnimatedContainer(
            duration: SacMotion.standard,
            curve: SacMotion.easeOut,
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor, width: 1),
            ),
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
            child: Column(
              children: [
                SizedBox(
                  height: _kLogoSize,
                  width: double.infinity,
                  child: Center(
                    child: _MutedMasterHonorLogo(
                      muted: isMuted,
                      child: MasterHonorLogo(
                        imageUrl: item.masterImage,
                        name: item.name,
                        size: _kLogoSize,
                        color: accent,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: _kCounterSlot,
                  child: visual == MasterHonorGridVisual.inactive
                      ? Align(
                          alignment: Alignment.center,
                          child: _StatusCaption(
                            label: item.displayStatusLabel ?? 'No vigente',
                            background: AppColors.pendingBg,
                            foreground: AppColors.pendingDark,
                          ),
                        )
                      : showCounter && item.totalGroups > 0
                          ? Align(
                              alignment: Alignment.center,
                              child: _CounterPill(
                                label:
                                    '${item.completedGroups}/${item.totalGroups}',
                                emphasized:
                                    visual == MasterHonorGridVisual.awarded,
                                color: accent,
                              ),
                            )
                          : null,
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Text(
                      item.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: nameWeight,
                        color: nameColor,
                        height: 1.25,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                SizedBox(
                  height: _kProgressSlot,
                  child: showBar
                      ? Align(
                          alignment: Alignment.bottomCenter,
                          child: _ThinProgressBar(
                            progress: progress,
                            color: accent,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (reduce) return card;

    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: card,
      ),
    );
  }
}

class _CounterPill extends StatelessWidget {
  const _CounterPill({
    required this.label,
    required this.emphasized,
    required this.color,
  });

  final String label;
  final bool emphasized;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: emphasized ? color.withValues(alpha: 0.16) : context.sac.border,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: emphasized ? color : context.sac.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}

class _StatusCaption extends StatelessWidget {
  const _StatusCaption({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          height: 1.2,
          color: foreground,
        ),
      ),
    );
  }
}

class _ThinProgressBar extends StatelessWidget {
  const _ThinProgressBar({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final fillWidth = totalWidth * progress.clamp(0.0, 1.0);

          return ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Stack(
              children: [
                Container(
                  height: 3,
                  width: totalWidth,
                  color: context.sac.border,
                ),
                if (fillWidth > 0)
                  AnimatedContainer(
                    duration: SacMotion.standard,
                    curve: SacMotion.easeOut,
                    height: 3,
                    width: fillWidth,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MutedMasterHonorLogo extends StatelessWidget {
  const _MutedMasterHonorLogo({
    required this.muted,
    required this.child,
  });

  final bool muted;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!muted) return child;

    return ColorFiltered(
      colorFilter: _grayscaleFilter,
      child: Opacity(
        opacity: 0.58,
        child: child,
      ),
    );
  }
}

const ColorFilter _grayscaleFilter = ColorFilter.matrix(<double>[
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
]);
