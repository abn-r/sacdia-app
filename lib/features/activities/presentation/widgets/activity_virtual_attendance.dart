import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_state_panel.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_status_style.dart';

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
    HapticFeedback.lightImpact();
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
            // Optimistic: the answer shows at once and goes back on error.
            status: _pendingStatus ?? _rsvp?.status,
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
  final VoidCallback onGoing;
  final VoidCallback onNotGoing;
  final bool showTitle;

  const _IntentionCard({
    this.showTitle = true,
    required this.status,
    required this.onGoing,
    required this.onNotGoing,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final going = status == 'going';
    final notGoing = status == 'not_going';
    final String title;
    final String message;
    final SacStatusStyle style;
    if (going) {
      title = 'activities.widgets.rsvp_panel_going_title'.tr();
      message = 'activities.widgets.rsvp_panel_going_body'.tr();
      style = SacStatusStyle.of(
        context,
        SacStatusKind.validated,
        label: title,
      );
    } else if (notGoing) {
      title = 'activities.widgets.rsvp_panel_not_going_title'.tr();
      message = 'activities.widgets.rsvp_panel_not_going_body'.tr();
      style = SacStatusStyle.of(
        context,
        SacStatusKind.pending,
        label: title,
        icon: HugeIcons.strokeRoundedCancel01,
      );
    } else {
      title = 'activities.widgets.rsvp_panel_prompt_title'.tr();
      message = 'activities.widgets.rsvp_panel_prompt_body'.tr();
      style = SacStatusStyle.of(
        context,
        SacStatusKind.pending,
        label: title,
        icon: HugeIcons.strokeRoundedUserGroup,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTitle) ...[
          Text(
            'activities.widgets.rsvp_title'.tr(),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
        ],
        SacStatePanel(style: style, title: title, message: message),
        const SizedBox(height: 12),
        _IntentionSegmented(
          selected: going
              ? _Intention.going
              : notGoing
                  ? _Intention.notGoing
                  : null,
          onGoing: onGoing,
          onNotGoing: onNotGoing,
        ),
        const SizedBox(height: 10),
        Text(
          'activities.widgets.rsvp_change_note'.tr(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: c.textSecondary,
              ),
        ),
      ],
    );
  }
}

enum _Intention { notGoing, going }

/// Two-option segmented control. The selected background slides between the
/// options ([SacMotion.slide]); before the first answer there is no thumb, and
/// it appears under the chosen option without travelling from the other side.
class _IntentionSegmented extends StatefulWidget {
  final _Intention? selected;
  final VoidCallback onGoing;
  final VoidCallback onNotGoing;

  const _IntentionSegmented({
    required this.selected,
    required this.onGoing,
    required this.onNotGoing,
  });

  @override
  State<_IntentionSegmented> createState() => _IntentionSegmentedState();
}

class _IntentionSegmentedState extends State<_IntentionSegmented> {
  // False for the change from "no answer" to the first one: the thumb is
  // placed at once and only fades in.
  bool _slideThumb = false;

  @override
  void didUpdateWidget(_IntentionSegmented oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      _slideThumb = oldWidget.selected != null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final reduce = SacMotion.reduceMotionOf(context);
    final selected = widget.selected;
    final moveDuration =
        reduce || !_slideThumb ? Duration.zero : SacMotion.slide;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedAlign(
              key: const ValueKey('rsvp-thumb-align'),
              duration: moveDuration,
              curve: SacMotion.easeOut,
              alignment: selected == _Intention.going
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                heightFactor: 1,
                child: AnimatedOpacity(
                  key: const ValueKey('rsvp-thumb'),
                  duration: reduce ? Duration.zero : SacMotion.slide,
                  curve: SacMotion.easeOut,
                  opacity: selected == null ? 0 : 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                      boxShadow: [
                        BoxShadow(
                          color: c.shadow,
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _SegmentOption(
                  text: 'activities.widgets.rsvp_not_going'.tr(),
                  selected: selected == _Intention.notGoing,
                  onTap: widget.onNotGoing,
                ),
              ),
              Expanded(
                child: _SegmentOption(
                  text: 'activities.widgets.rsvp_going'.tr(),
                  selected: selected == _Intention.going,
                  onTap: widget.onGoing,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SegmentOption extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentOption({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Semantics(
      button: true,
      selected: selected,
      label: text,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: SacMotion.reduceMotionOf(context)
                  ? Duration.zero
                  : SacMotion.standard,
              curve: SacMotion.easeOut,
              style: TextStyle(
                fontSize: SacFontSize.titleMedium,
                fontWeight: FontWeight.w600,
                color: selected ? c.text : c.textSecondary,
              ),
              child: Text(text),
            ),
          ),
        ),
      ),
    );
  }
}
