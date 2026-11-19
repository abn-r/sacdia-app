import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/animations/sac_rolling_number.dart';
import 'package:sacdia_app/core/animations/sac_state_swap.dart';
import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_settings.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';

import '../../../biometric/presentation/providers/biometric_provider.dart';
import '../../domain/entities/active_session.dart';
import '../providers/active_sessions_providers.dart';
import '../utils/session_labels.dart';
import 'security_session_sheet.dart';

/// "Sesiones abiertas": the count, one row per open session (this device
/// first) and, below, "Cerrar las otras N sesiones". Another session opens a
/// sheet with its info and the close action; there is no trash button per row.
///
/// A closed session slides out to the right and the gap closes (see
/// [_SessionsList]); the count rolls.
class SecuritySessionsSection extends ConsumerStatefulWidget {
  const SecuritySessionsSection({super.key});

  @override
  ConsumerState<SecuritySessionsSection> createState() =>
      _SecuritySessionsSectionState();
}

class _SecuritySessionsSectionState
    extends ConsumerState<SecuritySessionsSection> {
  bool _revokingAll = false;

  Future<void> _openSession(ActiveSession session) async {
    final close = await showSessionSheet(context, session);
    if (close != true || !mounted) return;
    HapticFeedback.mediumImpact();

    final error = await ref
        .read(activeSessionsProvider.notifier)
        .revoke(session.sessionId);
    if (!mounted) return;
    if (error != null) {
      SacSnackBar.show(context, error, isError: true);
    } else {
      SacSnackBar.show(context, 'settings.security.session_closed'.tr());
    }
  }

  Future<void> _revokeOthers(int otherCount) async {
    if (otherCount == 0) return;
    final confirmed = await SacDialog.show(
      context,
      title: 'profile.active_sessions.ui.dialog_close_others_title'.tr(),
      content: otherCount == 1
          ? 'profile.active_sessions.ui.dialog_close_others_body_one'
              .tr(namedArgs: {'count': '$otherCount'})
          : 'profile.active_sessions.ui.dialog_close_others_body_other'
              .tr(namedArgs: {'count': '$otherCount'}),
      confirmLabel: 'profile.active_sessions.ui.action_close_sessions'.tr(),
      confirmIsDestructive: true,
    );
    if (confirmed != true || !mounted) return;

    // Biometric confirmation before closing every other session (no-op when
    // biometrics are off).
    final bioOk = await requireBiometricConfirmation(
      context,
      ref,
      reason: 'biometric.confirm_sensitive_action'.tr(),
    );
    if (!mounted) return;
    if (!bioOk) {
      SacSnackBar.show(
        context,
        'profile.active_sessions.ui.operation_cancelled'.tr(),
        isError: true,
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _revokingAll = true);
    final result =
        await ref.read(activeSessionsProvider.notifier).revokeAllOthers();
    if (!mounted) return;
    setState(() => _revokingAll = false);

    if (result.error != null) {
      SacSnackBar.show(context, result.error!, isError: true);
    } else {
      SacSnackBar.show(
        context,
        'settings.security.sessions_closed'.plural(
          result.count,
          namedArgs: {'count': '${result.count}'},
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(activeSessionsProvider);
    final sessions = async.value;

    final Widget body;
    if (sessions == null) {
      body = SacSettingsGroup(
        children: [
          if (async.hasError)
            SacErrorState.inline(
              message: userErrorMessage(async.error!),
              onRetry: () =>
                  ref.read(activeSessionsProvider.notifier).refresh(),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: SacLoading()),
            ),
        ],
      );
      return _frame(context, count: null, body: body);
    }
    if (sessions.isEmpty) return const SizedBox.shrink();

    final ordered = currentSessionFirst(sessions);
    final others = ordered.where((s) => !s.isCurrent).length;
    return _frame(
      context,
      count: ordered.length,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SacSettingsGroup(
            children: [
              _SessionsList(sessions: ordered, onTap: _openSession),
            ],
          ),
          const SizedBox(height: 12),
          SacStateSwap(
            child: others > 0
                ? Align(
                    key: const ValueKey('close-others'),
                    alignment: Alignment.center,
                    child: SacButton.text(
                      text: 'settings.security.close_others'.plural(
                        others,
                        namedArgs: {'count': '$others'},
                      ),
                      color: context.sac.error,
                      isLoading: _revokingAll,
                      onPressed:
                          _revokingAll ? null : () => _revokeOthers(others),
                    ),
                  )
                : Padding(
                    key: const ValueKey('only-this-device'),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'settings.security.only_this_phone'.tr(),
                      style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        color: context.sac.textTertiary,
                        height: 1.35,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _frame(BuildContext context, {int? count, required Widget body}) {
    final c = context.sac;
    final style = TextStyle(
      fontSize: SacFontSize.labelSmall,
      fontWeight: FontWeight.w600,
      color: c.textTertiary,
      letterSpacing: 0.8,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'settings.security.sessions_eyebrow'.tr().toUpperCase(),
                    style: style,
                  ),
                ),
              ),
              if (count != null)
                SacRollingNumber(
                  key: const ValueKey('sessions-count'),
                  value: count,
                  style: style,
                ),
            ],
          ),
        ),
        body,
      ],
    );
  }
}

// ── List with the closing motion (M5) ─────────────────────────────────────────

/// Rows of open sessions in an [AnimatedList]. A session that disappears from
/// [sessions] slides out to the right ([SacMotion.slide]) and then the gap
/// closes (200 ms). Under Reduced Motion it just goes. Any other change (a
/// session added, a rollback after a failure) rebuilds the list.
class _SessionsList extends StatefulWidget {
  const _SessionsList({required this.sessions, required this.onTap});

  final List<ActiveSession> sessions;
  final ValueChanged<ActiveSession> onTap;

  @override
  State<_SessionsList> createState() => _SessionsListState();
}

class _SessionsListState extends State<_SessionsList> {
  static const _slide = SacMotion.slide;
  static const _collapse = Duration(milliseconds: 200);

  GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  late List<ActiveSession> _shown = List.of(widget.sessions);
  bool _syncScheduled = false;

  @override
  void didUpdateWidget(covariant _SessionsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_syncScheduled || listEquals(oldWidget.sessions, widget.sessions)) {
      return;
    }
    _syncScheduled = true;
    // AnimatedListState cannot be changed while the tree is building.
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  void _sync() {
    _syncScheduled = false;
    if (!mounted) return;
    final next = widget.sessions;
    final nextIds = next.map((s) => s.sessionId).toSet();

    final remaining =
        _shown.where((s) => nextIds.contains(s.sessionId)).toList();
    final pureRemoval = remaining.length == next.length &&
        [for (var i = 0; i < next.length; i++) i]
            .every((i) => remaining[i].sessionId == next[i].sessionId);

    if (!pureRemoval) {
      setState(() {
        _listKey = GlobalKey<AnimatedListState>();
        _shown = List.of(next);
      });
      return;
    }

    final reduce = SacMotion.reduceMotionOf(context);
    final duration = reduce ? Duration.zero : _slide + _collapse;
    final slideFraction =
        reduce ? 1.0 : _slide.inMilliseconds / duration.inMilliseconds;
    for (var i = _shown.length - 1; i >= 0; i--) {
      if (nextIds.contains(_shown[i].sessionId)) continue;
      final removed = _shown.removeAt(i);
      _listKey.currentState?.removeItem(
        i,
        (context, animation) => _SlidingOut(
          animation: animation,
          slideFraction: slideFraction,
          child: _SessionRow(
            session: removed,
            showDivider: i > 0,
            onTap: () {},
          ),
        ),
        duration: duration,
      );
    }
    // Same rows, fresh data (last use).
    setState(() => _shown = List.of(next));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedList(
      key: _listKey,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      initialItemCount: _shown.length,
      itemBuilder: (context, index, animation) {
        final session = _shown[index];
        return _SessionRow(
          key: ValueKey('session-${session.sessionId}'),
          session: session,
          showDivider: index > 0,
          onTap: session.isCurrent ? null : () => widget.onTap(session),
        );
      },
    );
  }
}

/// Slides [child] to the right, then closes the height. [animation] runs from
/// 1 to 0 while the item is removed; [slideFraction] is the share of the total
/// time spent sliding.
class _SlidingOut extends StatelessWidget {
  const _SlidingOut({
    required this.animation,
    required this.slideFraction,
    required this.child,
  });

  final Animation<double> animation;
  final double slideFraction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final elapsed = 1 - animation.value;
        final slideT = SacMotion.easeOut
            .transform((elapsed / slideFraction).clamp(0.0, 1.0));
        final collapseT = slideFraction >= 1
            ? 0.0
            : SacMotion.easeOut.transform(
                ((elapsed - slideFraction) / (1 - slideFraction))
                    .clamp(0.0, 1.0),
              );
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: 1 - collapseT,
            child: FractionalTranslation(
              translation: Offset(slideT, 0),
              child: Opacity(opacity: 1 - slideT, child: child),
            ),
          ),
        );
      },
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    super.key,
    required this.session,
    required this.showDivider,
    required this.onTap,
  });

  final ActiveSession session;
  final bool showDivider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDivider) const SacSettingsDivider(),
        SacSettingsTile(
          icon: sessionIcon(session.deviceType),
          title: sessionDisplayName(session),
          subtitle: sessionSubtitle(session),
          trailing: session.isCurrent ? const _CurrentBadge() : null,
          onTap: onTap,
        ),
      ],
    );
  }
}

class _CurrentBadge extends StatelessWidget {
  const _CurrentBadge();

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.successContainer,
        borderRadius: BorderRadius.circular(AppTheme.radius2XS),
      ),
      child: Text(
        'settings.security.current_badge'.tr(),
        style: TextStyle(
          fontSize: SacFontSize.labelSmall,
          fontWeight: FontWeight.w600,
          color: c.onSuccessContainer,
        ),
      ),
    );
  }
}
