import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/sac_state_swap.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_profile_image.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';

import '../../domain/entities/activity_rsvp.dart';
import '../providers/activities_providers.dart';

/// Virtual activities: members mark intention. Staff confirms real attendance
/// among every section member.
class ActivityVirtualAttendance extends ConsumerStatefulWidget {
  final int activityId;
  final bool canConfirm;

  const ActivityVirtualAttendance({
    super.key,
    required this.activityId,
    required this.canConfirm,
  });

  @override
  ConsumerState<ActivityVirtualAttendance> createState() =>
      _ActivityVirtualAttendanceState();
}

class _ActivityVirtualAttendanceState
    extends ConsumerState<ActivityVirtualAttendance> {
  MyActivityRsvp? _rsvp;
  bool _loading = true;
  String? _pendingStatus;
  String? _error;

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
        .getMyRsvp(widget.activityId);
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _loading = false;
        _error = failure.message;
      }),
      (rsvp) => setState(() {
        _loading = false;
        _rsvp = rsvp;
      }),
    );
  }

  Future<void> _setStatus(String status) async {
    if (_pendingStatus != null || _rsvp?.status == status) return;
    setState(() {
      _pendingStatus = status;
      _error = null;
    });
    final result = await ref
        .read(activitiesRepositoryProvider)
        .setMyRsvp(widget.activityId, status);
    if (!mounted) return;
    result.fold(
      (_) {
        setState(() {
          _pendingStatus = null;
          _error = 'activities.widgets.rsvp_save_error'.tr();
        });
        SacSnackBar.show(
          context,
          'activities.widgets.rsvp_save_error'.tr(),
          isError: true,
        );
      },
      (saved) {
        setState(() {
          _pendingStatus = null;
          _rsvp = MyActivityRsvp(status: saved, eligible: true);
        });
        SacSnackBar.show(
          context,
          saved == 'not_going'
              ? 'activities.widgets.rsvp_saved_not_going'.tr()
              : 'activities.widgets.rsvp_saved_going'.tr(),
        );
      },
    );
  }

  Future<void> _openRoster() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => VirtualAttendanceSheet(activityId: widget.activityId),
    );
    if (saved != true || !mounted) return;
    ref.invalidate(activityDetailProvider(widget.activityId));
    SacSnackBar.show(context, 'activities.widgets.rsvp_saved'.tr());
  }

  @override
  Widget build(BuildContext context) {
    final eligible = _rsvp?.eligible ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_loading)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: SacAccent.of(context).color,
                ),
              ),
            ),
          )
        else if (eligible)
          _IntentionCard(
            status: _rsvp?.status,
            pendingStatus: _pendingStatus,
            onGoing: () => _setStatus('going'),
            onNotGoing: () => _setStatus('not_going'),
          ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.error,
                ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: SacPressable(
              listenOnly: true,
              child: TextButton(
                style: const ButtonStyle(enableFeedback: false),
                onPressed: _load,
                child: Text('common.retry'.tr()),
              ),
            ),
          ),
        ],
        if (widget.canConfirm) ...[
          if (eligible || _error != null) const SizedBox(height: 12),
          SacCard(
            onTap: _openRoster,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: SacAccent.of(context).color,
                    shape: BoxShape.circle,
                  ),
                  child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedUserCheck01,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'activities.widgets.rsvp_confirm_title'.tr(),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'activities.widgets.rsvp_confirm_body'.tr(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: context.sac.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  size: 18,
                  color: context.sac.textTertiary,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _IntentionCard extends StatelessWidget {
  final String? status;
  final String? pendingStatus;
  final VoidCallback onGoing;
  final VoidCallback onNotGoing;

  const _IntentionCard({
    required this.status,
    required this.pendingStatus,
    required this.onGoing,
    required this.onNotGoing,
  });

  @override
  Widget build(BuildContext context) {
    final going = status == 'going';
    final notGoing = status == 'not_going';
    final busy = pendingStatus != null;
    final body = going
        ? 'activities.widgets.rsvp_going_body'.tr()
        : notGoing
            ? 'activities.widgets.rsvp_not_going_body'.tr()
            : 'activities.widgets.rsvp_prompt'.tr();

    return SacCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'activities.widgets.rsvp_title'.tr(),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          SacStateSwap(
            child: Text(
              body,
              key: ValueKey(status ?? 'unset'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.sac.textSecondary,
                  ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _IntentionButton(
                  text: 'activities.widgets.rsvp_going'.tr(),
                  selected: going,
                  loading: pendingStatus == 'going',
                  onPressed: busy ? null : onGoing,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _IntentionButton(
                  text: 'activities.widgets.rsvp_not_going'.tr(),
                  selected: notGoing,
                  loading: pendingStatus == 'not_going',
                  onPressed: busy ? null : onNotGoing,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IntentionButton extends StatelessWidget {
  final String text;
  final bool selected;
  final bool loading;
  final VoidCallback? onPressed;

  const _IntentionButton({
    required this.text,
    required this.selected,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return SacButton.primary(
        text: text,
        isLoading: loading,
        onPressed: onPressed,
      );
    }
    return SacButton.outline(
      text: text,
      isLoading: loading,
      onPressed: onPressed,
    );
  }
}

class VirtualAttendanceSheet extends ConsumerStatefulWidget {
  final int activityId;

  const VirtualAttendanceSheet({super.key, required this.activityId});

  @override
  ConsumerState<VirtualAttendanceSheet> createState() =>
      _VirtualAttendanceSheetState();
}

class _VirtualAttendanceSheetState
    extends ConsumerState<VirtualAttendanceSheet> {
  List<AttendanceRosterMember> _members = const [];
  final Set<String> _selected = {};
  bool _loading = true;
  bool _saving = false;
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
      (members) => setState(() {
        _loading = false;
        _members = members;
        _selected
          ..clear()
          ..addAll(
            members.where((member) => member.confirmed).map((m) => m.userId),
          );
      }),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final result =
        await ref.read(activitiesRepositoryProvider).registerAttendance(
              widget.activityId,
              _selected.toList(),
            );
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _saving = false;
        _error = failure.message;
      }),
      (_) => Navigator.of(context).pop(true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final visible = query.isEmpty
        ? _members
        : _members
            .where((member) => member.name.toLowerCase().contains(query))
            .toList();
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Material(
            color: context.sac.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.sac.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'activities.widgets.rsvp_confirm_title'.tr(),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'activities.widgets.rsvp_selected'.tr(
                          namedArgs: {'count': '${_selected.length}'},
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: context.sac.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        onChanged: (value) => setState(() => _query = value),
                        decoration: InputDecoration(
                          hintText: 'activities.widgets.rsvp_search'.tr(),
                          prefixIcon: const HugeIcon(
                            icon: HugeIcons.strokeRoundedSearch01,
                            size: 20,
                          ),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                Expanded(
                  child: _loading
                      ? Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: SacAccent.of(context).color,
                            ),
                          ),
                        )
                      : visible.isEmpty
                          ? Center(
                              child: Text(
                                'activities.widgets.rsvp_empty'.tr(),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: visible.length,
                              itemBuilder: (context, index) {
                                final member = visible[index];
                                final checked =
                                    _selected.contains(member.userId);
                                return SacPressable(
                                  listenOnly: true,
                                  child: CheckboxListTile(
                                    enableFeedback: false,
                                    value: checked,
                                    onChanged: _saving
                                        ? null
                                        : (value) {
                                            setState(() {
                                              if (value == true) {
                                                _selected.add(member.userId);
                                              } else {
                                                _selected.remove(member.userId);
                                              }
                                            });
                                          },
                                    secondary: _MemberAvatar(member: member),
                                    title: Text(member.name),
                                    subtitle: Text(_badge(member.rsvp)),
                                    controlAffinity:
                                        ListTileControlAffinity.trailing,
                                    activeColor: SacAccent.of(context).color,
                                  ),
                                );
                              },
                            ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_saving) ...[
                        Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: SacAccent.of(context).color,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'activities.widgets.rsvp_confirm_saving'.tr(),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      SacButton.primary(
                        text: 'activities.widgets.rsvp_save'.tr(),
                        onPressed: _loading || _saving ? null : _save,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _badge(String? rsvp) {
    if (rsvp == 'going') return 'activities.widgets.rsvp_badge_going'.tr();
    if (rsvp == 'not_going') {
      return 'activities.widgets.rsvp_badge_not_going'.tr();
    }
    return 'activities.widgets.rsvp_badge_none'.tr();
  }
}

class _MemberAvatar extends StatelessWidget {
  final AttendanceRosterMember member;

  const _MemberAvatar({required this.member});

  @override
  Widget build(BuildContext context) {
    final image = member.imageUrl;
    if (image != null && image.isNotEmpty) {
      return ClipOval(
        child: SacProfileImage(
          imageUrl: image,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
        ),
      );
    }
    final initial = member.name.isNotEmpty ? member.name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 18,
      backgroundColor: SacAccent.of(context).light,
      child: Text(
        initial,
        style: TextStyle(
          color: SacAccent.of(context).dark,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
