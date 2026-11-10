import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/consent/consent_error_messages.dart';
import '../../../../core/consent/consent_evidence.dart';
import '../../../../core/consent/consent_evidence_viewer.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_badge.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_card.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_member_avatar.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../domain/entities/join_request.dart';
import '../providers/members_providers.dart';
import '../utils/join_request_labels.dart';

// Pieces of the «Verificar consentimiento» screen. They only draw: every flag
// and action comes from the view.

/// Left inset of the checklist dividers: row padding + icon well + gap.
const double _kStepTextInset = 14 + 36 + 12;

String _formatUploadedAt(BuildContext context, DateTime at) =>
    DateFormat.yMMMd(context.locale.toString()).add_jm().format(at.toLocal());

// ── Header ────────────────────────────────────────────────────────────────

/// Avatar, name, «Menor sin cuenta · solicitó el …», status badge and a short
/// hint. The name is never the start of a sentence.
class ConsentHeader extends StatelessWidget {
  const ConsentHeader({
    super.key,
    required this.request,
    required this.verified,
    required this.verifyOnly,
  });

  final JoinRequest request;

  /// The consent is already verified (the approval is what failed).
  final bool verified;
  final bool verifyOnly;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final date = joinRequestAbsoluteDate(request.requestedAt);
    final subtitle = date == null
        ? 'members.requests.minor_no_account'.tr()
        : tr('members.requests.minor_requested', namedArgs: {'date': date});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SacMemberAvatar(
              imageUrl: request.avatar,
              name: joinRequestAvatarName(request),
              semanticLabel: joinRequestDisplayName(request),
              size: 56,
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
                  const SizedBox(height: 8),
                  verified
                      ? SacBadge.success(
                          label: 'members.requests.status_verified'.tr(),
                          icon: HugeIcons.strokeRoundedCheckmarkBadge01,
                        )
                      : SacBadge.warning(
                          label: 'members.requests.status_pending'.tr(),
                          icon: HugeIcons.strokeRoundedClock01,
                        ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          verifyOnly
              ? 'members.consent.header_hint_verify_only'.tr()
              : 'members.consent.header_hint'.tr(),
          style: TextStyle(
            fontSize: SacFontSize.bodyMedium,
            color: c.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ── Section label and group container ─────────────────────────────────────

class ConsentSectionLabel extends StatelessWidget {
  const ConsentSectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    // Starts at the card edge, like the other screen content.
    return Padding(
      padding: EdgeInsets.zero,
      child: Semantics(
        header: true,
        child: Text(
          label,
          style: TextStyle(
            fontSize: SacFontSize.titleSmall,
            fontWeight: FontWeight.w700,
            color: context.sac.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Rows in one rounded container, split by hairline dividers.
class ConsentGroup extends StatelessWidget {
  const ConsentGroup({super.key, required this.children, this.dividerIndent});

  final List<Widget> children;
  final double? dividerIndent;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return SacCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: dividerIndent ?? 14,
                  color: c.borderLight,
                ),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

// ── Checklist ─────────────────────────────────────────────────────────────

/// The three steps: form uploaded, form reviewed (the checkbox) and confirmed.
class ConsentChecklist extends ConsumerWidget {
  const ConsentChecklist({
    super.key,
    required this.assignmentId,
    required this.hasEvidence,
    required this.pendingFile,
    required this.reviewed,
    required this.reviewEnabled,
    required this.onToggleReviewed,
    required this.confirmed,
    required this.verifyOnly,
  });

  final String assignmentId;
  final bool hasEvidence;
  final bool pendingFile;
  final bool reviewed;

  /// The form is uploaded and nothing is in flight: the row can be toggled.
  final bool reviewEnabled;
  final VoidCallback onToggleReviewed;
  final bool confirmed;
  final bool verifyOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formDone = hasEvidence && !pendingFile;
    // Only a form that exists has a date to fetch (same provider the evidence
    // row uses, so it is one request).
    final uploadedAt = hasEvidence
        ? ref
            .watch(joinRequestConsentEvidenceProvider(assignmentId))
            .value
            ?.uploadedAt
        : null;
    final formSubtitle = !formDone
        ? 'members.consent.step_form_missing'.tr()
        : uploadedAt == null
            ? 'members.requests.form_uploaded_short'.tr()
            : 'members.consent.evidence_uploaded_on'.tr(
                namedArgs: {'date': _formatUploadedAt(context, uploadedAt)});

    return ConsentGroup(
      dividerIndent: _kStepTextInset,
      children: [
        _StepRow(
          number: 1,
          done: formDone,
          title: 'members.consent.evidence_title'.tr(),
          subtitle: formSubtitle,
        ),
        _StepRow(
          number: 2,
          done: reviewed,
          title: 'members.consent.step_review'.tr(),
          subtitle: reviewed ? null : 'members.consent.step_review_hint'.tr(),
          checkbox: confirmed
              ? null
              : _ReviewCheckbox(
                  value: reviewed,
                  enabled: reviewEnabled,
                  onChanged: onToggleReviewed,
                ),
          onTap: confirmed || !reviewEnabled ? null : onToggleReviewed,
        ),
        _StepRow(
          number: 3,
          done: confirmed,
          title: verifyOnly
              ? 'members.consent.step_confirm'.tr()
              : 'members.consent.confirm'.tr(),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.done,
    required this.title,
    this.subtitle,
    this.checkbox,
    this.onTap,
  });

  final int number;
  final bool done;
  final String title;
  final String? subtitle;
  final Widget? checkbox;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            _StepWell(number: number, done: done),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: SacFontSize.titleSmall,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                      height: 1.2,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        color: c.textSecondary,
                        height: 1.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (checkbox != null) ...[const SizedBox(width: 8), checkbox!],
          ],
        ),
      ),
    );

    if (checkbox == null) {
      return Semantics(
        // «done» is announced as text: the icon alone says nothing.
        value: done ? '✓' : null,
        child: row,
      );
    }
    return MergeSemantics(
      child: SacPressable(
        onTap: onTap,
        enabled: onTap != null,
        semanticButton: false,
        child: row,
      ),
    );
  }
}

class _StepWell extends StatelessWidget {
  const _StepWell({required this.number, required this.done});

  final int number;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done ? c.successContainer : c.surfaceVariant,
        borderRadius: BorderRadius.circular(AppTheme.radiusXS + 2),
      ),
      child: done
          ? HugeIcon(
              icon: HugeIcons.strokeRoundedTick02,
              size: 20,
              color: c.onSuccessContainer,
            )
          : Text(
              '$number',
              style: TextStyle(
                fontSize: SacFontSize.titleSmall,
                fontWeight: FontWeight.w700,
                color: c.textSecondary,
              ),
            ),
    );
  }
}

class _ReviewCheckbox extends StatelessWidget {
  const _ReviewCheckbox({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    return Checkbox(
      value: value,
      onChanged: enabled ? (_) => onChanged() : null,
      activeColor: accent.color,
      checkColor: accent.onColor,
      side: WidgetStateBorderSide.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return BorderSide.none;
        return BorderSide(
          color: states.contains(WidgetState.disabled)
              ? c.borderLight
              : c.textTertiary,
          width: 1.5,
        );
      }),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius2XS + 2),
      ),
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}

// ── Guardians ─────────────────────────────────────────────────────────────

/// «Tutores»: one key/value row per guardian, «Custodia del club» and, when
/// given, the custody hand-off row. Draws nothing when there is no row.
class ConsentGuardiansSection extends StatelessWidget {
  const ConsentGuardiansSection(
      {super.key, required this.consent, this.handoff});

  final JoinRequestConsent? consent;

  /// The «Entregar a la familia» row (`ClaimCodeSection`).
  final Widget? handoff;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final consent = this.consent;
    final rows = <Widget>[
      for (final guardian in consent?.guardians ?? const <ConsentGuardianRef>[])
        ConsentKeyValueRow(
          label: guardian.isPrimary
              ? 'members.requests.guardian_primary'.tr()
              : 'members.requests.guardian'.tr(),
          value: guardian.relationshipTypeName == null ||
                  guardian.relationshipTypeName!.trim().isEmpty
              ? guardian.displayName
              : '${guardian.displayName} (${guardian.relationshipTypeName})',
        ),
      if (consent?.isCustody ?? false)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'members.requests.custody'.tr(),
              style: TextStyle(
                fontSize: SacFontSize.bodyMedium,
                color: c.textSecondary,
              ),
            ),
          ),
        ),
      if (handoff != null) handoff!,
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConsentSectionLabel('members.consent.guardians'.tr()),
        const SizedBox(height: 8),
        ConsentGroup(children: rows),
        const SizedBox(height: 24),
      ],
    );
  }
}

class ConsentKeyValueRow extends StatelessWidget {
  const ConsentKeyValueRow(
      {super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
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
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: SacFontSize.bodyMedium,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Evidence ──────────────────────────────────────────────────────────────

/// Current signed form with its signed URL. The URL is requested when the
/// screen opens and is never cached. [onRequestGone] fires on a 404
/// `MR_NOT_FOUND` for someone who only verifies.
class ConsentCurrentEvidence extends ConsumerWidget {
  const ConsentCurrentEvidence({
    super.key,
    required this.assignmentId,
    required this.title,
    this.onRequestGone,
  });

  final String assignmentId;
  final String title;
  final VoidCallback? onRequestGone;

  String _uploadedLabel(BuildContext context, ConsentEvidenceAccess access) {
    final at = access.uploadedAt;
    if (at == null) return '';
    final date = _formatUploadedAt(context, at);
    final by = access.uploadedByDisplayName;
    return by == null
        ? 'members.consent.evidence_uploaded_on'.tr(namedArgs: {'date': date})
        : 'members.consent.evidence_uploaded_by'
            .tr(namedArgs: {'name': by, 'date': date});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final evidence =
        ref.watch(joinRequestConsentEvidenceProvider(assignmentId));
    ref.listen(joinRequestConsentEvidenceProvider(assignmentId), (_, next) {
      if (next.hasError && isRequestNotFound(next.error)) onRequestGone?.call();
    });

    return SacCard(
      padding: EdgeInsets.zero,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: evidence.when(
            loading: () => Row(
              children: [
                const SacLoadingSmall(),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'members.consent.evidence_loading'.tr(),
                    style: TextStyle(
                      fontSize: SacFontSize.bodyMedium,
                      color: c.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            error: (error, _) => Row(
              children: [
                Expanded(
                  child: Text(
                    isConsentEvidenceUnavailable(error)
                        ? consentErrorMessage(error)
                        : 'members.consent.evidence_load_error'.tr(),
                    style: TextStyle(
                      fontSize: SacFontSize.bodyMedium,
                      color: c.onErrorContainer,
                    ),
                  ),
                ),
                if (!isConsentEvidenceUnavailable(error))
                  SacButton.text(
                    text: 'core.consent.retry'.tr(),
                    onPressed: () => ref.invalidate(
                      joinRequestConsentEvidenceProvider(assignmentId),
                    ),
                  ),
              ],
            ),
            data: (access) {
              final uploaded = _uploadedLabel(context, access);
              return Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.surfaceVariant,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusXS + 2),
                    ),
                    child: HugeIcon(
                      icon: access.isPdf
                          ? HugeIcons.strokeRoundedPdf01
                          : HugeIcons.strokeRoundedImage01,
                      size: 20,
                      color: c.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: SacFontSize.titleSmall,
                            fontWeight: FontWeight.w600,
                            color: c.text,
                            height: 1.2,
                          ),
                        ),
                        if (uploaded.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            uploaded,
                            style: TextStyle(
                              fontSize: SacFontSize.bodySmall,
                              color: c.textSecondary,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SacButton(
                    text: 'members.consent.evidence_view_short'.tr(),
                    variant: SacButtonVariant.outline,
                    size: SacButtonSize.small,
                    borderRadius: AppTheme.radiusFull,
                    onPressed: () =>
                        openConsentEvidence(context, access, title: title),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Light block for «no form yet». The actions (upload or a note) go inside.
class ConsentEmptyEvidence extends StatelessWidget {
  const ConsentEmptyEvidence({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(
              child: Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedFile01,
                  size: 28,
                  color: c.textTertiary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'members.consent.evidence_empty_title'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: SacFontSize.titleSmall,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'members.consent.evidence_empty_hint'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: SacFontSize.bodySmall,
                color: c.textSecondary,
              ),
            ),
            if (child != null) ...[const SizedBox(height: 12), child!],
          ],
        ),
      ),
    );
  }
}

/// Small secondary note under the evidence («solo verificas», «ya verificada»).
class ConsentNote extends StatelessWidget {
  const ConsentNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: SacFontSize.bodySmall,
        color: context.sac.textSecondary,
      ),
    );
  }
}

// ── Bottom bar ────────────────────────────────────────────────────────────

/// Pinned bar with the primary action. Normal mode: four-eyes notice, helper,
/// error and the confirm pill. When the consent is verified but the approval
/// failed ([approvalFailedReason] set): the reason and the retry pill.
class ConsentBottomBar extends StatelessWidget {
  const ConsentBottomBar({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
    this.notice,
    this.helper,
    this.error,
    this.approvalFailedReason,
    this.retryLabel,
  });

  /// Confirm label (normal mode).
  final String label;
  final bool busy;

  /// `null` disables the pill.
  final VoidCallback? onPressed;
  final String? notice;
  final String? helper;
  final Object? error;
  final String? approvalFailedReason;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    final failedReason = approvalFailedReason;
    final bodySmall = TextStyle(
      fontSize: SacFontSize.bodySmall,
      color: c.textSecondary,
    );
    final errorStyle = TextStyle(
      fontSize: SacFontSize.bodyMedium,
      color: c.onErrorContainer,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.background,
        border: Border(top: BorderSide(color: c.borderLight)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (failedReason != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'members.consent.verified_not_approved'
                        .tr(namedArgs: {'reason': failedReason}),
                    style: errorStyle,
                  ),
                )
              else if (notice != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.warningContainer,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedAlert02,
                            size: 18,
                            color: c.onWarningContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              notice!,
                              style: TextStyle(
                                fontSize: SacFontSize.bodySmall,
                                color: c.onWarningContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (failedReason == null && helper != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(helper!, style: bodySmall),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(consentErrorMessage(error), style: errorStyle),
                ),
              SacButton.primary(
                text: failedReason != null ? (retryLabel ?? label) : label,
                icon: failedReason != null
                    ? HugeIcons.strokeRoundedRefresh
                    : HugeIcons.strokeRoundedCheckmarkCircle01,
                isLoading: busy,
                borderRadius: AppTheme.radiusFull,
                backgroundColor: accent.color,
                textColor: accent.onColor,
                onPressed: busy ? null : onPressed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
