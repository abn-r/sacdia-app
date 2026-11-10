import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_member_avatar.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';

import '../../domain/entities/join_request.dart';
import '../utils/join_request_groups.dart';
import '../utils/join_request_labels.dart';

/// Horizontal space before the text: row padding + avatar + gap. The group
/// divider is indented by this much.
const double kJoinRequestRowTextInset = 14 + 40 + 12;

/// Second line of a request row (and of the detail sheet header) for [group].
String joinRequestSubtitle(JoinRequest request, JoinRequestGroup group) {
  final ago = joinRequestRelativeDate(request.requestedAt);
  final consent = request.consent;
  switch (group) {
    case JoinRequestGroup.ready:
      if (consent != null) return 'members.consent.badge_verified'.tr();
      return ago == null
          ? 'members.requests.own_account'.tr()
          : tr('members.requests.own_account_date', namedArgs: {'date': ago});
    case JoinRequestGroup.review:
      if (consent?.viewerVerifyBlock != null) {
        return 'members.requests.other_must_verify'.tr();
      }
      final guardian = consent?.guardians
          .where((g) => g.isPrimary && g.displayName.trim().isNotEmpty)
          .firstOrNull;
      return guardian == null
          ? 'members.requests.form_uploaded'.tr()
          : tr('members.requests.form_uploaded_by',
              namedArgs: {'name': guardian.displayName});
    case JoinRequestGroup.waiting:
      return ago == null
          ? 'members.requests.no_form'.tr()
          : tr('members.requests.no_form_date', namedArgs: {'date': ago});
  }
}

/// One row of a request group: avatar, name, next-step subtitle and the
/// trailing action for that step.
///
/// - [onAction]: the pill («Aprobar» for ready, «Revisar» for review).
/// - [onReject]: enables swipe-to-reject and the «Rechazar» accessibility action.
/// - [onTap]: row body tap; `null` makes the row inert.
class JoinRequestRow extends StatelessWidget {
  const JoinRequestRow({
    super.key,
    required this.request,
    required this.group,
    this.onTap,
    this.onAction,
    this.onReject,
    this.isProcessing = false,
  });

  final JoinRequest request;
  final JoinRequestGroup group;
  final VoidCallback? onTap;
  final VoidCallback? onAction;
  final VoidCallback? onReject;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final hasPill =
        group != JoinRequestGroup.waiting && (onAction != null || isProcessing);

    Widget row = SacPressable(
      onTap: onTap,
      enabled: onTap != null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              SacMemberAvatar(
                imageUrl: request.avatar,
                name: joinRequestAvatarName(request),
                semanticLabel: joinRequestDisplayName(request),
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      joinRequestDisplayName(request),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: SacFontSize.titleSmall,
                        fontWeight: FontWeight.w600,
                        color: c.text,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      joinRequestSubtitle(request, group),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        color: c.textSecondary,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasPill) ...[
                const SizedBox(width: 8),
                _ActionPill(
                  group: group,
                  isLoading: isProcessing,
                  onTap: onAction,
                ),
              ] else if (group == JoinRequestGroup.waiting &&
                  onTap != null) ...[
                const SizedBox(width: 8),
                ExcludeSemantics(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    size: 18,
                    color: c.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    final reject = onReject;
    if (reject == null || isProcessing) return row;

    row = Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: 'members.join_request.reject'.tr()):
            reject,
      },
      child: row,
    );
    return Dismissible(
      key: ValueKey('join-request-${request.assignmentId}'),
      direction: DismissDirection.endToStart,
      // The confirmation dialog decides; the list refreshes from the provider.
      confirmDismiss: (_) async {
        reject();
        return false;
      },
      background: _RejectBackground(),
      child: ColoredBox(color: c.surface, child: row),
    );
  }
}

/// Red area revealed while swiping a row to the left.
class _RejectBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return ColoredBox(
      color: c.error,
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedCancel01,
                size: 18,
                color: c.onError,
              ),
              const SizedBox(width: 6),
              Text(
                'members.join_request.reject'.tr(),
                style: TextStyle(
                  fontSize: SacFontSize.bodyMedium,
                  fontWeight: FontWeight.w700,
                  color: c.onError,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact filled pill; the hit area is 44pt tall even if the pill is shorter.
class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.group,
    required this.isLoading,
    required this.onTap,
  });

  final JoinRequestGroup group;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = SacAccent.of(context);
    final isApprove = group == JoinRequestGroup.ready;
    // Actions follow the user's accent, like every action in the app. Green
    // stays for status (the group dot, «consentimiento verificado»).
    final background = accent.color;
    final foreground = accent.onColor;
    final label = isApprove
        ? 'members.join_request.approve'.tr()
        : 'members.requests.review'.tr();

    return SacPressable(
      onTap: isLoading ? null : onTap,
      enabled: !isLoading && onTap != null,
      semanticLabel: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        child: Center(
          child: ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: SizedBox(
                  height: 32,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLoading)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: foreground,
                          ),
                        )
                      else
                        // Text only: keeps the pill short so the row's
                        // subtitle has room.
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: SacFontSize.bodyMedium,
                            fontWeight: FontWeight.w700,
                            color: foreground,
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
