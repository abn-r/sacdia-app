import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/animations/sac_state_swap.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/instructor_field.dart';
import 'package:sacdia_app/core/widgets/instructor_picker.dart';
import 'package:sacdia_app/core/widgets/instructor_selection.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';

import '../../domain/entities/user_honor.dart';
import '../../domain/entities/user_honor_update.dart';
import '../providers/honors_providers.dart';

/// Where the card is, from the honor's instructor and its proposal (6.5).
enum _Stage { none, current, pending, rejected }

bool _same(InstructorSelection a, InstructorSelection b) =>
    a.kind == b.kind &&
    (a.isUser
        ? a.userId == b.userId
        : a.displayName.toLowerCase() == b.displayName.toLowerCase());

/// "Instructor o instructora" of an APPROVED honor (D11). The honor is frozen:
/// the member can only propose an instructor, and the Local Field approves or
/// rejects it. The current instructor never changes until it is approved, so
/// "approved" has no state of its own: the person is just the instructor.
///
/// Reads `instructor` and `instructor_proposal` from the list; proposing
/// and withdrawing go through [instructorProposalActionsNotifierProvider]
/// (never the `PATCH`).
class InstructorProposalCard extends ConsumerStatefulWidget {
  const InstructorProposalCard({super.key, required this.userHonor});

  final UserHonor userHonor;

  @override
  ConsumerState<InstructorProposalCard> createState() =>
      _InstructorProposalCardState();
}

class _InstructorProposalCardState extends ConsumerState<InstructorProposalCard>
    with WidgetsBindingObserver {
  bool _busy = false;
  String? _error;

  UserHonor get _honor => widget.userHonor;
  InstructorSelection get _current =>
      _honor.instructor ?? const InstructorSelection.none();

  _Stage get _stage {
    final proposal = _honor.instructorProposal;
    if (proposal != null && proposal.isPending) return _Stage.pending;
    if (proposal != null && proposal.isRejected) return _Stage.rejected;
    return _current.isNone ? _Stage.none : _Stage.current;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// No push in v1 (D8): a pending proposal is re-read when the app returns.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _stage == _Stage.pending) {
      ref.invalidate(userHonorsProvider);
    }
  }

  InstructorProposalActionsNotifier get _actions =>
      ref.read(instructorProposalActionsNotifierProvider.notifier);

  Future<void> _propose() async {
    final picked = await InstructorPicker.show(context);
    if (picked == null || picked.isNone || !mounted) return;
    if (_same(picked, _current)) {
      setState(
          () => _error = 'honors.evidence.instructor_proposal_unchanged'.tr());
      return;
    }
    final confirmed = await SacDialog.show(
      context,
      title: 'honors.evidence.instructor_proposal_confirm_title'
          .tr(namedArgs: {'name': picked.displayName}),
      content: 'honors.evidence.instructor_proposal_confirm_body'.tr(),
      confirmLabel: 'honors.evidence.instructor_proposal_confirm'.tr(),
      cancelLabel: 'honors.evidence.instructor_proposal_dismiss'.tr(),
    );
    if (confirmed != true || !mounted) return;
    await _run(
      () => _actions.propose(
        userId: _honor.userId,
        honorId: _honor.honorId,
        instructor: picked,
      ),
      fallback: 'honors.evidence.instructor_proposal_error',
    );
  }

  Future<void> _cancel() async {
    final confirmed = await SacDialog.show(
      context,
      title: 'honors.evidence.instructor_proposal_cancel_title'.tr(),
      content: _current.isNone
          ? 'honors.evidence.instructor_proposal_cancel_body_none'.tr()
          : 'honors.evidence.instructor_proposal_cancel_body'
              .tr(namedArgs: {'instructor': _current.displayName}),
      confirmLabel: 'honors.evidence.instructor_proposal_cancel'.tr(),
      cancelLabel: 'honors.evidence.instructor_proposal_back'.tr(),
      confirmIsDestructive: true,
    );
    if (confirmed != true || !mounted) return;
    await _run(
      () => _actions.cancel(userId: _honor.userId, honorId: _honor.honorId),
      fallback: 'honors.evidence.instructor_proposal_cancel_error',
    );
  }

  Future<void> _run(
    Future<Failure?> Function() action, {
    required String fallback,
  }) async {
    final actions = _actions;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    final failure = await action();
    if (!mounted) return;
    final onCard = failure == null ? null : _messageFor(failure, actions);
    setState(() {
      _busy = false;
      _error = onCard;
    });
    if (failure != null && onCard == null) {
      SacSnackBar.showMessenger(messenger, fallback.tr(), isError: true);
    }
  }

  /// Text for the card, or null when the failure only deserves the banner.
  String? _messageFor(Failure failure, InstructorProposalActionsNotifier a) {
    final code = failure.errorCode;
    if (failure.code == 429) {
      return 'honors.evidence.instructor_proposal_rate_limited'.tr();
    }
    if (failure.code == 409 ||
        InstructorProposalErrorCode.stale.contains(code)) {
      // Changed elsewhere: re-read, and the card redraws in the right state.
      a.refresh();
      return 'honors.evidence.status_changed'.tr();
    }
    if (code == InstructorProposalErrorCode.unchanged) {
      return 'honors.evidence.instructor_proposal_unchanged'.tr();
    }
    return InstructorErrorCode.fieldMessage(code);
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the notifier alive across the awaited request.
    ref.watch(instructorProposalActionsNotifierProvider);
    final stage = _stage;
    final reduce = SacMotion.reduceMotionOf(context);
    final swap = SacStateSwap(
      child: Column(
        key: ValueKey(stage),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...switch (stage) {
            _Stage.pending => _pending(context),
            _Stage.rejected => _rejected(context),
            _ => _settled(context),
          },
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Center(child: SacLoadingSmall()),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: context.sac.error),
                ),
              ),
            ),
        ],
      ),
    );
    // The height follows the content (M26); Reduced Motion drops it and keeps
    // only the fade.
    return SacCard(
      child: reduce
          ? swap
          : AnimatedSize(
              duration: SacMotion.switcher,
              curve: SacMotion.easeOut,
              alignment: Alignment.topCenter,
              child: swap,
            ),
    );
  }

  Widget _action(String key, dynamic icon, VoidCallback onPressed) => Align(
        alignment: Alignment.centerLeft,
        child: SacButton.ghost(
          text: key.tr(),
          icon: icon,
          isEnabled: !_busy,
          onPressed: _busy ? null : onPressed,
        ),
      );

  /// No instructor / with instructor: read-only, plus the way to propose.
  List<Widget> _settled(BuildContext context) => [
        InstructorField(
          selection: _current,
          readOnly: true,
          onChanged: (_) {},
        ),
        _action(
          _current.isNone
              ? 'honors.evidence.instructor_proposal_cta'
              : 'honors.evidence.instructor_proposal_change',
          HugeIcons.strokeRoundedUserAdd01,
          _propose,
        ),
        _help(context),
      ];

  List<Widget> _rejected(BuildContext context) {
    final c = context.sac;
    final theme = Theme.of(context).textTheme;
    final reason = _honor.instructorProposal?.rejectionReason;
    final title = 'honors.evidence.instructor_proposal_rejected'.tr();
    return [
      Semantics(
        liveRegion: true,
        label: reason == null
            ? title
            : '$title. ${'honors.evidence.instructor_proposal_reason'.tr(namedArgs: {
                    'reason': reason
                  })}',
        excludeSemantics: true,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.titleSmall
                    ?.copyWith(color: c.error, fontWeight: FontWeight.w600),
              ),
              if (reason != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'honors.evidence.instructor_proposal_reason'
                        .tr(namedArgs: {'reason': reason}),
                    style: theme.bodyMedium?.copyWith(color: c.text),
                  ),
                ),
            ],
          ),
        ),
      ),
      ..._settled(context),
    ];
  }

  List<Widget> _pending(BuildContext context) {
    final c = context.sac;
    final proposed = _honor.instructorProposal?.instructor;
    final keeps = _current.isNone
        ? 'honors.evidence.instructor_proposal_pending_keeps_none'.tr()
        : 'honors.evidence.instructor_proposal_pending_keeps'
            .tr(namedArgs: {'instructor': _current.displayName});
    final proposedSpoken = proposed == null
        ? ''
        : proposed.isUser
            ? '${proposed.displayName}, ${'instructor.local_field_person'.tr().toLowerCase()}'
            : '${proposed.displayName}, ${'instructor.unverified'.tr().toLowerCase()}';
    final label = 'honors.evidence.instructor_proposal_semantics_pending'.tr(
      namedArgs: {
        'proposed': proposedSpoken,
        'current': _current.isNone
            ? 'honors.evidence.instructor_proposal_current_none'.tr()
            : _current.displayName,
      },
    );
    return [
      Semantics(
        liveRegion: true,
        label: label,
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SacBadge(
                label: 'honors.evidence.instructor_proposal_pending'.tr(),
                icon: HugeIcons.strokeRoundedClock01,
                variant: SacBadgeVariant.neutral,
              ),
            ),
            if (proposed != null) ...[
              const SizedBox(height: 12),
              InstructorField(
                selection: proposed,
                readOnly: true,
                onChanged: (_) {},
              ),
            ],
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text(
                keeps,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: c.textSecondary),
              ),
            ),
          ],
        ),
      ),
      _action(
        'honors.evidence.instructor_proposal_replace',
        HugeIcons.strokeRoundedUserEdit01,
        _propose,
      ),
      _action(
        'honors.evidence.instructor_proposal_cancel',
        HugeIcons.strokeRoundedCancel01,
        _cancel,
      ),
    ];
  }

  Widget _help(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 2, left: 4),
        child: Text(
          'instructor.help'.tr(),
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: context.sac.textSecondary),
        ),
      );
}
