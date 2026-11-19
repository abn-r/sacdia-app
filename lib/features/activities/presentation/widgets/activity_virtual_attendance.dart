import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/animations/sac_state_swap.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';

import '../../domain/entities/activity_rsvp.dart';
import '../providers/activities_providers.dart';
import 'activity_detail_row.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';

/// Virtual activities: members mark their intention (going / not going). Staff
/// confirms real attendance from the manual attendance screen.
class ActivityVirtualAttendance extends ConsumerStatefulWidget {
  final int activityId;

  /// Label above the intention card ("TU ASISTENCIA"). Shown only when the
  /// member can answer, so it never sits over an empty block.
  final String? eyebrow;

  const ActivityVirtualAttendance({
    super.key,
    required this.activityId,
    this.eyebrow,
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
              child: SacLoadingSmall(color: SacAccent.of(context).color),
            ),
          )
        else if (eligible) ...[
          if (widget.eyebrow != null) ActivityEyebrow(widget.eyebrow!),
          _IntentionCard(
            showTitle: widget.eyebrow == null,
            status: _rsvp?.status,
            pendingStatus: _pendingStatus,
            onGoing: () => _setStatus('going'),
            onNotGoing: () => _setStatus('not_going'),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.sac.error,
                ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: SacButton.text(
              text: 'common.retry'.tr(),
              onPressed: _load,
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
  final bool showTitle;

  const _IntentionCard({
    this.showTitle = true,
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
          if (showTitle) ...[
            Text(
              'activities.widgets.rsvp_title'.tr(),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
          ],
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
