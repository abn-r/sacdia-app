import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/theme/sac_font_size.dart';
import 'package:sacdia_app/core/widgets/fixed_input_icon_slot.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_frosted_footer.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_member_avatar.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_grouped_section.dart';

import '../../domain/entities/activity_rsvp.dart';
import '../providers/activities_providers.dart';

/// Mark attendance by hand for every member of the activity's sections:
/// "Missing" and "Present" groups with a search field; a switch moves a row
/// to the other group. Saving sends the full attendee list (it replaces the
/// previous one) and pops with `true`.
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
  Set<String> _initial = const {};
  bool _loading = true;
  bool _saving = false;
  bool _animateMoves = false;
  String? _error;
  String _query = '';

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
        setState(() {
          _loading = false;
          _members = members;
          _initial = confirmed;
          _selected
            ..clear()
            ..addAll(confirmed);
        });
        // Rows only glide between groups after the first paint.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _animateMoves = true);
        });
      },
    );
  }

  bool get _changed => !setEquals(_selected, _initial);

  void _toggle(String userId, bool value) {
    if (_saving) return;
    setState(() {
      if (value) {
        _selected.add(userId);
      } else {
        _selected.remove(userId);
      }
    });
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
        SacSnackBar.showMessenger(
          messenger,
          'activities.attendance.saved'.tr(),
          isSuccess: true,
        );
        navigator.pop(true);
      },
    );
  }

  String _badge(String? rsvp) {
    if (rsvp == 'going') return 'activities.widgets.rsvp_badge_going'.tr();
    if (rsvp == 'not_going') {
      return 'activities.widgets.rsvp_badge_not_going'.tr();
    }
    return 'activities.widgets.rsvp_badge_none'.tr();
  }

  Widget _row(AttendanceRosterMember member) {
    return _MemberSwitchRow(
      key: ValueKey('manual-${member.userId}'),
      name: member.name,
      imageUrl: member.imageUrl,
      detail: widget.showRsvp ? _badge(member.rsvp) : null,
      value: _selected.contains(member.userId),
      animateIn: _animateMoves,
      onChanged: _saving ? null : (v) => _toggle(member.userId, v),
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
    final visible = query.isEmpty
        ? _members
        : _members.where((m) => m.name.toLowerCase().contains(query)).toList();
    final missing = visible.where((m) => !_selected.contains(m.userId));
    final present = visible.where((m) => _selected.contains(m.userId));
    final c = context.sac;

    return ListView(
      padding: const EdgeInsets.only(bottom: SacFrostedFooter.height + 16),
      children: [
        _searchField(),
        if (_members.isEmpty)
          _Message('activities.widgets.rsvp_empty'.tr())
        else if (visible.isEmpty)
          _Message('activities.attendance.no_match'.tr())
        else ...[
          if (missing.isNotEmpty)
            SacGroupedSection(
              label: 'activities.attendance.group_missing'.tr(),
              rollCount: true,
              children: [for (final m in missing) _row(m)],
            ),
          if (present.isNotEmpty)
            SacGroupedSection(
              label: 'activities.attendance.group_present'.tr(),
              rollCount: true,
              children: [for (final m in present) _row(m)],
            ),
        ],
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
    return Scaffold(
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

/// Avatar, name (+ optional line) and a switch. When it first appears after
/// the screen loaded (the row moved to the other group) it fades and grows in
/// over [SacMotion.standard].
class _MemberSwitchRow extends StatefulWidget {
  const _MemberSwitchRow({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.detail,
    required this.value,
    required this.animateIn,
    required this.onChanged,
  });

  final String name;
  final String? imageUrl;
  final String? detail;
  final bool value;
  final bool animateIn;
  final ValueChanged<bool>? onChanged;

  @override
  State<_MemberSwitchRow> createState() => _MemberSwitchRowState();
}

class _MemberSwitchRowState extends State<_MemberSwitchRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: SacMotion.standard,
  );
  late final Animation<double> _curve =
      CurvedAnimation(parent: _controller, curve: SacMotion.easeOut);

  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller.value = 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Decided once, on first build: later rebuilds keep the settled state.
    if (_started) return;
    _started = true;
    if (widget.animateIn && !SacMotion.reduceMotionOf(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context).color;
    final detail = widget.detail;
    return FadeTransition(
      opacity: _curve,
      child: SizeTransition(
        sizeFactor: _curve,
        alignment: Alignment.topCenter,
        child: Semantics(
          container: true,
          label: widget.name,
          toggled: widget.value,
          enabled: widget.onChanged != null,
          onTap: widget.onChanged == null
              ? null
              : () => widget.onChanged!(!widget.value),
          child: ExcludeSemantics(
            child: InkWell(
              onTap: widget.onChanged == null
                  ? null
                  : () => widget.onChanged!(!widget.value),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
                  child: Row(
                    children: [
                      SacMemberAvatar(
                        imageUrl: widget.imageUrl,
                        name: widget.name,
                        size: 32,
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
                          value: widget.value,
                          onChanged: widget.onChanged,
                          activeThumbColor: accent,
                          activeTrackColor: accent.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
