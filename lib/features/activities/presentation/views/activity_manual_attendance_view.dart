import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/theme/sac_font_size.dart';
import 'package:sacdia_app/core/widgets/fixed_input_icon_slot.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_filter_chip.dart';
import 'package:sacdia_app/core/widgets/sac_frosted_footer.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_member_avatar.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_grouped_section.dart';

import '../../domain/entities/activity_rsvp.dart';
import '../providers/activities_providers.dart';

enum _Filter { all, missing, present }

/// Mark attendance by hand for every member of the activity's sections: one
/// alphabetical list whose rows never move while marking. The whole row is
/// the tap target; each toggle shows an undo notice. Saving sends the full
/// attendee list (it replaces the previous one) and pops with `true`.
class ActivityManualAttendanceView extends ConsumerStatefulWidget {
  const ActivityManualAttendanceView({
    super.key,
    required this.activityId,
    required this.activityName,
    this.showRsvp = false,
  });

  final int activityId;
  final String activityName;

  /// Shows each member's RSVP answer (virtual activities only).
  final bool showRsvp;

  @override
  ConsumerState<ActivityManualAttendanceView> createState() =>
      _ActivityManualAttendanceViewState();
}

class _ActivityManualAttendanceViewState
    extends ConsumerState<ActivityManualAttendanceView> {
  List<AttendanceRosterMember> _members = const [];
  final Set<String> _selected = {};

  /// Rows that stopped matching the filter after a toggle and are still
  /// collapsing out.
  final Set<String> _leaving = {};
  Set<String> _initial = const {};
  bool _loading = true;
  bool _saving = false;
  bool _saved = false;
  String? _error;
  String _query = '';
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref
        .read(activitiesRepositoryProvider)
        .getAttendanceRoster(widget.activityId);
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _loading = false;
        _error = failure.message;
      }),
      (members) {
        final confirmed =
            members.where((m) => m.confirmed).map((m) => m.userId).toSet();
        final sorted = [...members]..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
        setState(() {
          _loading = false;
          _members = sorted;
          _initial = confirmed;
          _selected
            ..clear()
            ..addAll(confirmed);
          _leaving.clear();
        });
      },
    );
  }

  bool get _changed => !setEquals(_selected, _initial);

  bool _matchesFilter(bool present) => switch (_filter) {
        _Filter.all => true,
        _Filter.missing => !present,
        _Filter.present => present,
      };

  void _toggle(AttendanceRosterMember member, {bool announce = true}) {
    if (_saving) return;
    final id = member.userId;
    final nowPresent = !_selected.contains(id);
    HapticFeedback.lightImpact();
    setState(() {
      if (nowPresent) {
        _selected.add(id);
      } else {
        _selected.remove(id);
      }
      if (_matchesFilter(nowPresent)) {
        _leaving.remove(id);
      } else {
        _leaving.add(id);
      }
    });
    if (announce) _announce(member, nowPresent);
  }

  /// One notice at a time: it replaces any visible one.
  void _announce(AttendanceRosterMember member, bool nowPresent) {
    SacSnackBar.show(
      context,
      (nowPresent
              ? 'activities.attendance.marked_present'
              : 'activities.attendance.unmarked_present')
          .tr(namedArgs: {'name': member.name}),
      duration: const Duration(seconds: 3),
      margin: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        SacFrostedFooter.height - 24 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      action: SnackBarAction(
        label: 'activities.attendance.undo'.tr(),
        onPressed: () {
          if (mounted) _toggle(member, announce: false);
        },
      ),
    );
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    final result =
        await ref.read(activitiesRepositoryProvider).registerAttendance(
              widget.activityId,
              _selected.toList(),
            );
    if (!mounted) return;
    result.fold(
      (failure) {
        setState(() => _saving = false);
        SacSnackBar.showMessenger(
          messenger,
          failure.message.isNotEmpty
              ? failure.message
              : 'activities.attendance.save_error'.tr(),
          isError: true,
        );
      },
      (_) {
        _saved = true;
        SacSnackBar.showMessenger(
          messenger,
          'activities.attendance.saved'.tr(),
          isSuccess: true,
        );
        navigator.pop(true);
      },
    );
  }

  Future<void> _onPopInvoked(bool didPop) async {
    if (didPop) {
      // Drop a stale undo notice; the "saved" one stays.
      if (!_saved) SacSnackBar.hide(context);
      return;
    }
    if (_saving) return;
    final navigator = Navigator.of(context);
    final leave = await SacDialog.show(
      context,
      title: 'activities.attendance.unsaved_title'.tr(),
      content: 'activities.attendance.unsaved_body'.tr(),
      confirmLabel: 'activities.attendance.leave'.tr(),
      cancelLabel: 'activities.attendance.keep_marking'.tr(),
      confirmIsDestructive: true,
    );
    if (leave == true && mounted) navigator.pop();
  }

  String _badge(String? rsvp) {
    if (rsvp == 'going') return 'activities.widgets.rsvp_badge_going'.tr();
    if (rsvp == 'not_going') {
      return 'activities.widgets.rsvp_badge_not_going'.tr();
    }
    return 'activities.widgets.rsvp_badge_none'.tr();
  }

  Widget _row(AttendanceRosterMember member) {
    final id = member.userId;
    return _MemberRow(
      key: ValueKey('manual-$id'),
      name: member.name,
      imageUrl: member.imageUrl,
      detail: widget.showRsvp ? _badge(member.rsvp) : null,
      present: _selected.contains(id),
      collapsing: _leaving.contains(id),
      onToggle: _saving ? null : () => _toggle(member),
      onGone: () {
        if (mounted && _leaving.remove(id)) setState(() {});
      },
    );
  }

  Widget _searchField() {
    final c = context.sac;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: TextField(
        onChanged: (value) => setState(() => _query = value),
        decoration: InputDecoration(
          hintText: 'activities.widgets.rsvp_search'.tr(),
          // HugeIcon stretches to the 48px prefix slot unless the slot
          // centers it at a fixed size.
          prefixIcon: FixedInputIconSlot(
            icon: HugeIcons.strokeRoundedSearch01,
            color: c.textSecondary,
          ),
          prefixIconConstraints: FixedInputIconSlot.constraints,
          isDense: true,
        ),
      ),
    );
  }

  Widget _filters() {
    void select(_Filter filter) {
      if (filter == _filter) return;
      setState(() {
        _filter = filter;
        _leaving.clear();
      });
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Wrap(
        spacing: 8,
        children: [
          SacFilterChip(
            key: const ValueKey('manual-filter-all'),
            label: 'activities.attendance.filter_all'.tr(),
            selected: _filter == _Filter.all,
            onTap: () => select(_Filter.all),
          ),
          SacFilterChip(
            key: const ValueKey('manual-filter-missing'),
            label: 'activities.attendance.filter_missing'.tr(),
            count: _members.length - _selected.length,
            selected: _filter == _Filter.missing,
            onTap: () => select(_Filter.missing),
          ),
          SacFilterChip(
            key: const ValueKey('manual-filter-present'),
            label: 'activities.attendance.filter_present'.tr(),
            count: _selected.length,
            selected: _filter == _Filter.present,
            onTap: () => select(_Filter.present),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: SacLoading());
    if (_error != null && _members.isEmpty) {
      return SacErrorState(
        title: 'activities.attendance.load_error'.tr(),
        message: _error,
        onRetry: _load,
      );
    }
    final query = _query.trim().toLowerCase();
    final searched = query.isEmpty
        ? _members
        : _members.where((m) => m.name.toLowerCase().contains(query)).toList();
    final shown = [
      for (final m in searched)
        if (_matchesFilter(_selected.contains(m.userId)) ||
            _leaving.contains(m.userId))
          m,
    ];
    final settled = shown.where((m) => !_leaving.contains(m.userId)).length;
    final c = context.sac;

    return ListView(
      padding: const EdgeInsets.only(bottom: SacFrostedFooter.height + 16),
      children: [
        _searchField(),
        if (_members.isNotEmpty) _filters(),
        if (_members.isEmpty)
          _Message('activities.widgets.rsvp_empty'.tr())
        else if (shown.isEmpty)
          _Message(
            (query.isNotEmpty
                    ? 'activities.attendance.no_match'
                    : 'activities.attendance.filter_empty')
                .tr(),
          )
        else
          SacGroupedSection(
            label: 'activities.attendance.group_members'.tr(),
            count: settled,
            rollCount: true,
            children: [for (final m in shown) _row(m)],
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Text(_error!, style: TextStyle(color: c.error)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_changed,
      onPopInvokedWithResult: (didPop, _) => _onPopInvoked(didPop),
      child: Scaffold(
        backgroundColor: context.sac.background,
        appBar: SacTopBar(
          title: 'activities.attendance.manual'.tr(),
          subtitle: 'activities.attendance.present_count'.tr(
            namedArgs: {
              'count': '${_selected.length}',
              'total': '${_members.length}',
            },
          ),
        ),
        body: Stack(
          children: [
            Positioned.fill(child: _body()),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SacFrostedFooter(
                child: SacButton.primary(
                  key: const ValueKey('manual-save'),
                  text: 'activities.attendance.save'.tr(),
                  isLoading: _saving,
                  onPressed: _loading || _saving || !_changed ? null : _save,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: SacFontSize.bodyMedium,
          color: context.sac.textSecondary,
        ),
      ),
    );
  }
}

/// Whole-row tap target: avatar with a check badge when present, name (+
/// optional line) and a switch. Present rows are tinted with the accent. With
/// [collapsing] set the row fades and collapses out over [SacMotion.standard]
/// and then calls [onGone]; clearing it again brings the row back.
class _MemberRow extends StatefulWidget {
  const _MemberRow({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.detail,
    required this.present,
    required this.collapsing,
    required this.onToggle,
    required this.onGone,
  });

  final String name;
  final String? imageUrl;
  final String? detail;
  final bool present;
  final bool collapsing;
  final VoidCallback? onToggle;
  final VoidCallback onGone;

  @override
  State<_MemberRow> createState() => _MemberRowState();
}

class _MemberRowState extends State<_MemberRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: SacMotion.standard,
    value: 1,
  )..addStatusListener(_onStatus);
  late final Animation<double> _curve =
      CurvedAnimation(parent: _controller, curve: SacMotion.easeOut);

  @override
  void initState() {
    super.initState();
    if (widget.collapsing) _collapse();
  }

  @override
  void didUpdateWidget(_MemberRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.collapsing == oldWidget.collapsing) return;
    if (widget.collapsing) {
      _collapse();
    } else {
      _controller.forward();
    }
  }

  void _collapse() {
    _controller.duration =
        SacMotion.reduceMotionOf(context) ? Duration.zero : SacMotion.standard;
    _controller.reverse();
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.dismissed || !widget.collapsing) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.collapsing) widget.onGone();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    final reduce = SacMotion.reduceMotionOf(context);
    final tint = reduce ? SacMotion.reducedFade : SacMotion.switcher;
    final detail = widget.detail;
    final onToggle = widget.onToggle;
    final present = widget.present;

    return FadeTransition(
      opacity: _curve,
      child: SizeTransition(
        sizeFactor: _curve,
        alignment: Alignment.topCenter,
        child: Semantics(
          container: true,
          button: true,
          label: (present
                  ? 'activities.attendance.row_present'
                  : 'activities.attendance.row_absent')
              .tr(namedArgs: {'name': widget.name}),
          toggled: present,
          enabled: onToggle != null,
          onTap: onToggle,
          child: ExcludeSemantics(
            child: InkWell(
              onTap: onToggle,
              child: AnimatedContainer(
                duration: tint,
                curve: SacMotion.easeOut,
                constraints: const BoxConstraints(minHeight: 56),
                color: present
                    ? accent.color.withValues(alpha: 0.10)
                    : Colors.transparent,
                padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        SacMemberAvatar(
                          imageUrl: widget.imageUrl,
                          name: widget.name,
                          size: 32,
                        ),
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: AnimatedScale(
                            scale: present ? 1 : 0,
                            duration: tint,
                            curve: SacMotion.easeOut,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: accent.color,
                                shape: BoxShape.circle,
                                border: Border.all(color: c.surface, width: 2),
                              ),
                              child: Center(
                                child: HugeIcon(
                                  icon: HugeIcons.strokeRoundedTick02,
                                  size: 9,
                                  color: accent.onColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: SacFontSize.titleMedium,
                              fontWeight: FontWeight.w500,
                              color: c.text,
                            ),
                          ),
                          if (detail != null)
                            Text(
                              detail,
                              style: TextStyle(
                                fontSize: SacFontSize.bodySmall,
                                color: c.textTertiary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    SacPressable(
                      listenOnly: true,
                      child: Switch(
                        value: present,
                        onChanged: onToggle == null ? null : (_) => onToggle(),
                        activeThumbColor: accent.color,
                        activeTrackColor: accent.color.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
