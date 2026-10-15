import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';

/// Intrinsic-width mode switcher. Sliding clip shows a duplicate active row.
class MembersModeSwitcher extends StatefulWidget {
  const MembersModeSwitcher({
    super.key,
    required this.index,
    required this.onChanged,
    required this.showContinuations,
    required this.pendingRequests,
    required this.pendingContinuations,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final bool showContinuations;
  final int pendingRequests;
  final int pendingContinuations;

  @override
  State<MembersModeSwitcher> createState() => _MembersModeSwitcherState();
}

class _SwitcherRect {
  const _SwitcherRect({required this.left, required this.width});

  final double left;
  final double width;

  static _SwitcherRect lerp(_SwitcherRect a, _SwitcherRect b, double t) {
    return _SwitcherRect(
      left: a.left + (b.left - a.left) * t,
      width: a.width + (b.width - a.width) * t,
    );
  }
}

class _MembersModeSwitcherState extends State<MembersModeSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<GlobalKey> _keys;
  _SwitcherRect _from = const _SwitcherRect(left: 0, width: 0);
  _SwitcherRect _to = const _SwitcherRect(left: 0, width: 0);
  bool _measured = false;

  List<_ModeTab> get _tabs {
    return [
      _ModeTab(label: 'members.view.members_tab'.tr()),
      _ModeTab(
        label: 'members.view.requests_tab'.tr(),
        badge: widget.pendingRequests,
      ),
      if (widget.showContinuations)
        _ModeTab(
          label: 'members.view.continuations_tab'.tr(),
          badge: widget.pendingContinuations,
        ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _keys = List.generate(3, (_) => GlobalKey());
    _controller = AnimationController(
      vsync: this,
      duration: SacMotion.switcher,
      value: 1,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure(snap: true));
  }

  @override
  void didUpdateWidget(covariant MembersModeSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    final countsChanged = oldWidget.pendingRequests != widget.pendingRequests ||
        oldWidget.pendingContinuations != widget.pendingContinuations ||
        oldWidget.showContinuations != widget.showContinuations;
    if (countsChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure(snap: true));
    } else if (oldWidget.index != widget.index && _measured) {
      _retarget(widget.index);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _measure({required bool snap}) {
    if (!mounted) return;
    final tabs = _tabs;
    var left = 0.0;
    final rects = <_SwitcherRect>[];
    for (var i = 0; i < tabs.length; i++) {
      final box = _keys[i].currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      rects.add(_SwitcherRect(left: left, width: box.size.width));
      left += box.size.width;
    }
    final safeIndex = widget.index.clamp(0, rects.length - 1);
    final next = rects[safeIndex];
    setState(() {
      if (snap || !_measured) {
        _from = next;
        _to = next;
        _controller.value = 1;
      } else {
        _from = _currentRect();
        _to = next;
        _play();
      }
      _measured = true;
    });
  }

  _SwitcherRect _currentRect() {
    return _SwitcherRect.lerp(
      _from,
      _to,
      SacMotion.easeOut.transform(_controller.value),
    );
  }

  void _retarget(int index) {
    final tabs = _tabs;
    if (index < 0 || index >= tabs.length) return;
    var left = 0.0;
    _SwitcherRect? next;
    for (var i = 0; i < tabs.length; i++) {
      final box = _keys[i].currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      if (i == index) {
        next = _SwitcherRect(left: left, width: box.size.width);
        break;
      }
      left += box.size.width;
    }
    if (next == null) return;
    setState(() {
      _from = _currentRect();
      _to = next!;
      _play();
    });
  }

  void _play() {
    final reduce = SacMotion.reduceMotionOf(context);
    if (reduce) {
      _controller.duration = Duration.zero;
      _controller.value = 1;
      return;
    }
    _controller.duration = SacMotion.switcher;
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final tabs = _tabs;
    final reduce = SacMotion.reduceMotionOf(context);

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Stack(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < tabs.length; i++)
                  SacPressable(
                    key: _keys[i],
                    onTap: () => widget.onChanged(i),
                    semanticLabel: tabs[i].semanticLabel,
                    child: _ModeSlot(
                      tab: tabs[i],
                      active: false,
                    ),
                  ),
              ],
            ),
            if (_measured)
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final t = reduce
                      ? 1.0
                      : SacMotion.easeOut.transform(_controller.value);
                  final rect = _SwitcherRect.lerp(_from, _to, t);
                  return Transform.translate(
                    offset: Offset(rect.left, 0),
                    child: IgnorePointer(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: c.shadow,
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: SizedBox(
                            width: rect.width,
                            height: 40,
                            child: OverflowBox(
                              alignment: Alignment.topLeft,
                              minWidth: 0,
                              maxWidth: double.infinity,
                              minHeight: 40,
                              maxHeight: 40,
                              child: Transform.translate(
                                offset: Offset(-rect.left, 0),
                                child: child,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final tab in tabs) _ModeSlot(tab: tab, active: true),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModeTab {
  const _ModeTab({required this.label, this.badge = 0});

  final String label;
  final int badge;

  String get semanticLabel => badge > 0 ? '$label $badge' : label;
}

class _ModeSlot extends StatelessWidget {
  const _ModeSlot({required this.tab, required this.active});

  final _ModeTab tab;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return SizedBox(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tab.label,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: active ? c.text : c.textSecondary,
              ),
            ),
            if (tab.badge > 0) ...[
              const SizedBox(width: 6),
              _ModeBadge(count: tab.badge),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
