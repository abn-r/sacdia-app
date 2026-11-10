import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_member_avatar.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../domain/entities/join_request.dart';
import '../utils/join_request_groups.dart';
import '../utils/join_request_labels.dart';

/// What the sheet asks the caller to do. The sheet closes itself first, so the
/// caller runs the action on its own context.
class JoinRequestSheetActions {
  const JoinRequestSheetActions({
    required this.onViewProfile,
    this.onApprove,
    this.onReview,
    this.onReject,
  });

  final VoidCallback onViewProfile;

  /// `null` hides the footer (the user cannot act on this request).
  final VoidCallback? onApprove;
  final VoidCallback? onReview;
  final VoidCallback? onReject;
}

/// Opens the request detail sheet (consent state, guardians, approve/reject).
Future<void> showJoinRequestDetailSheet(
  BuildContext context, {
  required JoinRequest request,
  required JoinRequestSheetActions actions,
}) {
  return showSacSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => JoinRequestDetailSheet(request: request, actions: actions),
  );
}

class JoinRequestDetailSheet extends StatelessWidget {
  const JoinRequestDetailSheet({
    super.key,
    required this.request,
    required this.actions,
  });

  final JoinRequest request;
  final JoinRequestSheetActions actions;

  /// Closes the sheet, then runs [action].
  void _close(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final group = joinRequestGroupOf(request);
    final consent = request.consent;
    final date = joinRequestAbsoluteDate(request.requestedAt);
    final subtitle = consent != null
        ? (date == null
            ? 'members.requests.minor_no_account'.tr()
            : tr('members.requests.minor_requested', namedArgs: {'date': date}))
        : (date == null
            ? 'members.requests.own_account'.tr()
            : tr('members.requests.own_requested', namedArgs: {'date': date}));
    final canAct = actions.onApprove != null ||
        actions.onReview != null ||
        actions.onReject != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXL),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            DecoratedBox(
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: const SizedBox(width: 40, height: 4),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(request: request, subtitle: subtitle),
                    if (consent != null) ...[
                      const SizedBox(height: 20),
                      _ConsentSection(consent: consent),
                    ],
                    const SizedBox(height: 8),
                    // Pulled left so the label lines up with the rows above.
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Transform.translate(
                        offset: const Offset(-17, 0),
                        child: SacButton.text(
                          text: 'members.requests.view_profile'.tr(),
                          onPressed: () =>
                              _close(context, actions.onViewProfile),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (canAct)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    if (actions.onReject != null)
                      Expanded(
                        child: SacButton.outline(
                          text: 'members.join_request.reject'.tr(),
                          textColor: c.error,
                          borderColor: c.error,
                          borderRadius: AppTheme.radiusFull,
                          onPressed: () => _close(context, actions.onReject!),
                        ),
                      ),
                    if (actions.onReject != null) const SizedBox(width: 12),
                    Expanded(child: _PrimaryAction(group, actions, _close)),
                  ],
                ),
              )
            else
              const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// «Aprobar» (ready) or «Revisar ficha» (review and waiting).
class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction(this.group, this.actions, this.close);

  final JoinRequestGroup group;
  final JoinRequestSheetActions actions;
  final void Function(BuildContext, VoidCallback) close;

  @override
  Widget build(BuildContext context) {
    if (group == JoinRequestGroup.ready) {
      final approve = actions.onApprove;
      // The accent, like every action; green is only for status.
      return SacButton.primary(
        text: 'members.join_request.approve'.tr(),
        borderRadius: AppTheme.radiusFull,
        backgroundColor: SacAccent.of(context).color,
        textColor: SacAccent.of(context).onColor,
        onPressed: approve == null ? null : () => close(context, approve),
      );
    }
    final review = actions.onReview;
    return SacButton.primary(
      text: 'members.requests.review_form'.tr(),
      borderRadius: AppTheme.radiusFull,
      backgroundColor: SacAccent.of(context).color,
      textColor: SacAccent.of(context).onColor,
      onPressed: review == null ? null : () => close(context, review),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.request, required this.subtitle});

  final JoinRequest request;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Row(
      children: [
        SacMemberAvatar(
          imageUrl: request.avatar,
          name: joinRequestAvatarName(request),
          semanticLabel: joinRequestDisplayName(request),
          size: 52,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                joinRequestDisplayName(request),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: SacFontSize.titleLarge,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: SacFontSize.bodyMedium,
                  color: c.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConsentSection extends StatelessWidget {
  const _ConsentSection({required this.consent});

  final JoinRequestConsent consent;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final rows = <Widget>[
      _KeyValueRow(
        label: 'members.requests.status'.tr(),
        value: consent.isVerified
            ? SacBadge.success(
                label: 'members.requests.status_verified'.tr(),
                icon: HugeIcons.strokeRoundedCheckmarkBadge01,
              )
            : SacBadge.warning(
                label: 'members.requests.status_pending'.tr(),
                icon: HugeIcons.strokeRoundedClock01,
              ),
      ),
      _KeyValueRow(
        label: 'members.consent.evidence_title'.tr(),
        value: _ValueText(
          consent.evidenceUploaded
              ? 'members.requests.form_uploaded_short'.tr()
              : 'members.requests.form_missing'.tr(),
        ),
      ),
      for (final guardian in consent.guardians)
        _KeyValueRow(
          label: guardian.isPrimary
              ? 'members.requests.guardian_primary'.tr()
              : 'members.requests.guardian'.tr(),
          value: _ValueText(
            guardian.relationshipTypeName == null ||
                    guardian.relationshipTypeName!.trim().isEmpty
                ? guardian.displayName
                : '${guardian.displayName} (${guardian.relationshipTypeName})',
          ),
        ),
      if (consent.isCustody)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'members.requests.custody'.tr(),
            style: TextStyle(
              fontSize: SacFontSize.bodyMedium,
              color: c.textSecondary,
            ),
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            'members.requests.consent_section'.tr(),
            style: TextStyle(
              fontSize: SacFontSize.titleSmall,
              fontWeight: FontWeight.w700,
              color: c.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 4),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: 1, color: c.borderLight),
          rows[i],
        ],
      ],
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: SacFontSize.bodyMedium,
                color: c.textSecondary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Align(alignment: Alignment.centerRight, child: value),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValueText extends StatelessWidget {
  const _ValueText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: TextAlign.end,
        style: TextStyle(
          fontSize: SacFontSize.bodyMedium,
          fontWeight: FontWeight.w600,
          color: context.sac.text,
        ),
      );
}
