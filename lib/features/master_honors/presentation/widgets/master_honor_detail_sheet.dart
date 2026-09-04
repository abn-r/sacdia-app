import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/features/master_honors/domain/entities/master_honor_roadmap.dart';
import 'package:sacdia_app/features/master_honors/presentation/widgets/master_honor_detail_presentation.dart';
import 'package:sacdia_app/features/master_honors/presentation/widgets/master_honor_logo.dart';

Future<void> showMasterHonorDetailSheet(
  BuildContext context,
  MasterHonorRoadmap item,
) {
  return showSacSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => MasterHonorDetailSheet(item: item),
  );
}

class MasterHonorDetailSheet extends StatefulWidget {
  const MasterHonorDetailSheet({super.key, required this.item});

  final MasterHonorRoadmap item;

  @override
  State<MasterHonorDetailSheet> createState() => _MasterHonorDetailSheetState();
}

class _MasterHonorDetailSheetState extends State<MasterHonorDetailSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(vsync: this, duration: SacMotion.modal);
    _fade = CurvedAnimation(parent: _enter, curve: SacMotion.easeOut);
    _scale = Tween<double>(begin: SacMotion.enterScale, end: 1).animate(
      CurvedAnimation(parent: _enter, curve: SacMotion.easeOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (SacMotion.reduceMotionOf(context)) {
      _enter.value = 1;
    } else if (!_enter.isAnimating && _enter.value == 0) {
      _enter.forward();
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final accent = masterHonorDetailAccent(item);
    final status = MasterHonorDetailStatus.of(item);
    final logoSize =
        (MediaQuery.sizeOf(context).width * 0.34).clamp(120.0, 148.0);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final c = context.sac;
    final reduce = SacMotion.reduceMotionOf(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: c.shadow,
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.border.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: FadeTransition(
                    opacity: _fade,
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: EdgeInsets.fromLTRB(
                        20,
                        16,
                        20,
                        28 + bottomInset,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            ScaleTransition(
                              scale: _scale,
                              child: MasterHonorLogo(
                                imageUrl: item.masterImage,
                                name: item.name,
                                size: logoSize,
                                color: accent,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              item.name,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: c.text,
                                height: 1.15,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _StatusPill(
                              label: status.label,
                              background: status.background,
                              foreground: status.foreground,
                            ),
                            if (item.totalGroups > 0) ...[
                              const SizedBox(height: 18),
                              _MasterHonorProgressBar(
                                progress: masterHonorGroupProgress(item),
                                color: accent,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                masterHonorProgressCaption(item),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: c.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (masterHonorShowsPercentCaption(item)) ...[
                                const SizedBox(height: 2),
                                Text(
                                  masterHonorPercentCaption(item),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: c.textTertiary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                            const SizedBox(height: 22),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Requisitos',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: c.text,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (item.requirementGroups.isEmpty)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Aún no hay requisitos configurados para esta maestría.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: c.textTertiary,
                                  ),
                                ),
                              )
                            else
                              ...item.requirementGroups
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                final delayMs = entry.key.clamp(0, 11) *
                                    SacMotion.stagger.inMilliseconds;
                                return _StaggeredEnter(
                                  delay: Duration(milliseconds: delayMs),
                                  reduceMotion: reduce,
                                  child: _RequirementDetailCard(
                                    group: entry.value,
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: foreground,
          height: 1,
        ),
      ),
    );
  }
}

class _MasterHonorProgressBar extends StatefulWidget {
  const _MasterHonorProgressBar({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  State<_MasterHonorProgressBar> createState() =>
      _MasterHonorProgressBarState();
}

class _MasterHonorProgressBarState extends State<_MasterHonorProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _fill;
  bool? _reduceMotion;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: SacMotion.standard,
    );
    _fill = Tween<double>(
      begin: 0,
      end: widget.progress.clamp(0.0, 1.0),
    ).animate(
      CurvedAnimation(parent: _controller, curve: SacMotion.easeOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = SacMotion.reduceMotionOf(context);
    if (_reduceMotion == reduce) return;
    _reduceMotion = reduce;

    if (reduce) {
      _controller.value = 1;
    } else if (_controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(_MasterHonorProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress == widget.progress) return;

    final reduce = _reduceMotion ?? SacMotion.reduceMotionOf(context);
    final current = reduce ? widget.progress : _fill.value;
    _fill = Tween<double>(
      begin: current.clamp(0.0, 1.0),
      end: widget.progress.clamp(0.0, 1.0),
    ).animate(
      CurvedAnimation(parent: _controller, curve: SacMotion.easeOut),
    );
    if (reduce) {
      _controller.value = 1;
    } else {
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 6,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _fill,
          builder: (context, _) {
            return Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: context.sac.surfaceVariant),
                Transform.scale(
                  alignment: Alignment.centerLeft,
                  scaleX: _fill.value.clamp(0.0, 1.0),
                  child: ColoredBox(color: widget.color),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StaggeredEnter extends StatefulWidget {
  const _StaggeredEnter({
    required this.delay,
    required this.reduceMotion,
    required this.child,
  });

  final Duration delay;
  final bool reduceMotion;
  final Widget child;

  @override
  State<_StaggeredEnter> createState() => _StaggeredEnterState();
}

class _StaggeredEnterState extends State<_StaggeredEnter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _dy;
  Timer? _delayedStart;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: SacMotion.standard,
    );
    _fade = CurvedAnimation(parent: _controller, curve: SacMotion.easeOut);
    _dy = Tween<double>(begin: 8, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: SacMotion.easeOut),
    );

    if (widget.reduceMotion) {
      _controller.value = 1;
    } else {
      _delayedStart = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void didUpdateWidget(_StaggeredEnter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reduceMotion && !oldWidget.reduceMotion) {
      _delayedStart?.cancel();
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _delayedStart?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reduceMotion) return widget.child;

    return FadeTransition(
      opacity: _fade,
      child: AnimatedBuilder(
        animation: _dy,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _dy.value),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _RequirementDetailCard extends StatefulWidget {
  const _RequirementDetailCard({required this.group});

  final MasterHonorRoadmapGroup group;

  @override
  State<_RequirementDetailCard> createState() => _RequirementDetailCardState();
}

class _RequirementDetailCardState extends State<_RequirementDetailCard> {
  bool _expanded = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final c = context.sac;
    final reduce = SacMotion.reduceMotionOf(context);
    final passed = group.passed;
    final label = masterHonorRequirementLabel(group);
    final unit = group.isCategoryCount ? 'especialidades' : 'opciones';
    final detail = '${group.currentCount}/${group.minimumRequired} $unit';
    final completed =
        group.options.where((option) => option.completed).toList();
    final incomplete =
        group.options.where((option) => !option.completed).toList();
    final collapses = masterHonorCollapsesIncompleteOptions(group);
    final showIncomplete = !collapses || _expanded;
    final accent = passed ? AppColors.secondary : AppColors.observedDark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HugeIcon(
                icon: passed
                    ? HugeIcons.strokeRoundedCheckmarkCircle02
                    : HugeIcons.strokeRoundedCircle,
                size: 18,
                color: accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (masterHonorShowsRequirementDescription(group)) ...[
            const SizedBox(height: 8),
            Text(
              group.description!.trim(),
              style: TextStyle(
                fontSize: 12,
                color: c.textSecondary,
                height: 1.35,
              ),
            ),
          ],
          if (completed.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...completed.map((option) => _OptionRow(option: option)),
          ],
          if (showIncomplete && incomplete.isNotEmpty) ...[
            if (completed.isEmpty) const SizedBox(height: 10),
            ...incomplete.map((option) => _OptionRow(option: option)),
          ],
          if (collapses) ...[
            const SizedBox(height: 4),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => _setPressed(true),
              onTapUp: (_) => _setPressed(false),
              onTapCancel: () => _setPressed(false),
              onTap: () => setState(() => _expanded = !_expanded),
              child: AnimatedScale(
                scale: (!reduce && _pressed) ? SacMotion.pressScale : 1,
                duration: SacMotion.press,
                curve: SacMotion.easeOut,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _expanded
                              ? 'Ocultar'
                              : completed.isEmpty
                                  ? 'Elige ${group.minimumRequired} de ${group.options.length} $unit'
                                  : 'Ver ${incomplete.length} restantes',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: reduce ? Duration.zero : SacMotion.standard,
                        curve: SacMotion.easeOut,
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedArrowDown01,
                          size: 16,
                          color: c.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.option});

  final MasterHonorRoadmapOption option;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(
            icon: option.completed
                ? HugeIcons.strokeRoundedTick02
                : HugeIcons.strokeRoundedCircle,
            size: 14,
            color: option.completed
                ? AppColors.secondary
                : context.sac.textTertiary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              option.label,
              style: TextStyle(
                fontSize: 12,
                color: context.sac.textSecondary,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
