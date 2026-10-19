import 'package:dartz/dartz.dart' show Either;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/consent/consent_error_messages.dart';
import '../../../../core/consent/consent_evidence.dart';
import '../../../../core/consent/consent_evidence_uploader.dart';
import '../../../../core/consent/consent_evidence_viewer.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/sac_badge.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_card.dart';
import '../../../../core/widgets/sac_dialog.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../auth/presentation/providers/acting_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/dependent.dart';
import '../../domain/usecases/revoke_guardianship.dart';
import '../family_error_messages.dart';
import '../family_outcome_messages.dart';
import '../providers/family_providers.dart';
import '../widgets/consent_badge.dart';
import '../widgets/dependent_avatar.dart';
import '../widgets/dependent_card.dart';
import '../widgets/profile_switcher_sheet.dart';

/// Detalle de un menor: tutores, consentimiento, invitar a un segundo tutor y
/// dejar la tutoría (FP-61).
class DependentDetailView extends ConsumerStatefulWidget {
  const DependentDetailView({
    super.key,
    required this.dependentId,
    this.picker = const ConsentEvidencePicker(),
  });

  final String dependentId;

  /// Inyectable para probar sin los plugins de cámara/archivos.
  final ConsentEvidencePicker picker;

  @override
  ConsumerState<DependentDetailView> createState() =>
      _DependentDetailViewState();
}

class _DependentDetailViewState extends ConsumerState<DependentDetailView> {
  bool _busy = false;

  void _toast(String message, {bool isError = false}) {
    if (!mounted) return;
    SacSnackBar.show(context, message, isError: isError);
  }

  Future<void> _invite(DependentDetail detail) async {
    setState(() => _busy = true);
    final result =
        await ref.read(familyActionsProvider).issueLinkCode(widget.dependentId);
    if (!mounted) return;
    setState(() => _busy = false);

    result.fold(
      (failure) => _toast(familyErrorMessage(failure), isError: true),
      (issued) => _showCode(detail.summary, issued),
    );
  }

  Future<void> _showCode(DependentSummary dependent, IssuedLinkCode issued) {
    final expires = DateFormat.yMMMd(context.locale.toString())
        .add_jm()
        .format(issued.expiresAt.toLocal());
    final message = 'family.detail.share_message'.tr(namedArgs: {
      'name': dependent.firstName,
      'code': issued.code,
      'when': expires,
    });

    return SacDialog.present<void>(
      context,
      builder: (dialogContext) => SacDialog(
        title: 'family.detail.code_title'.tr(),
        icon: HugeIcons.strokeRoundedKey01,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(
              issued.code,
              style: Theme.of(dialogContext).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                    color: dialogContext.sac.text,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'family.detail.code_expires'.tr(namedArgs: {'when': expires}),
              style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                    color: dialogContext.sac.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SacDialogAction(
            label: 'family.detail.copy'.tr(),
            style: SacDialogActionStyle.cancel,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: issued.code));
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              _toast('family.detail.copied'.tr());
            },
          ),
          SacDialogAction(
            label: 'family.detail.share'.tr(),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await Share.share(message);
            },
          ),
        ],
      ),
    );
  }

  Future<Either<Failure, ConsentEvidenceReceipt>> _uploadForm(
    ConsentEvidenceLocalFile file,
  ) {
    return ref
        .read(familyActionsProvider)
        .uploadConsentEvidence(widget.dependentId, file);
  }

  void _onFormUploaded(ConsentEvidenceReceipt receipt) {
    _toast('family.detail.form_uploaded_toast'.tr());
  }

  /// Abre la ficha subida. La URL es firmada y caduca: se pide al tocar y no se
  /// guarda en ningún lado.
  Future<void> _viewForm() async {
    setState(() => _busy = true);
    final result = await ref
        .read(familyActionsProvider)
        .getConsentEvidence(widget.dependentId);
    if (!mounted) return;
    setState(() => _busy = false);

    await result.fold(
      (failure) async => _toast(consentErrorMessage(failure), isError: true),
      (access) => openConsentEvidence(
        context,
        access,
        title: 'family.detail.form_title'.tr(),
      ),
    );
  }

  Future<void> _leave(DependentDetail detail, DependentGuardian me) async {
    final name = detail.summary.firstName;
    final confirmed = await SacDialog.show(
      context,
      title: 'family.detail.leave_title'.tr(namedArgs: {'name': name}),
      content: outcomeMessage(predictLeaveOutcome(detail), name),
      confirmLabel: 'family.detail.leave_confirm'.tr(),
      confirmIsDestructive: true,
    );
    if (confirmed != true || !mounted) return;
    await _revoke(me.guardianshipId, removedByPrimary: false, leaving: true);
  }

  Future<void> _remove(DependentGuardian other) async {
    final confirmed = await SacDialog.show(
      context,
      title: 'family.detail.remove_title'.tr(
        namedArgs: {'name': other.displayName},
      ),
      content: 'family.detail.remove_body'.tr(),
      confirmLabel: 'family.detail.remove_confirm'.tr(),
      confirmIsDestructive: true,
    );
    if (confirmed != true || !mounted) return;
    await _revoke(other.guardianshipId, removedByPrimary: true, leaving: false);
  }

  Future<void> _revoke(
    String guardianshipId, {
    required bool removedByPrimary,
    required bool leaving,
  }) async {
    final name = ref
            .read(dependentDetailProvider(widget.dependentId))
            .valueOrNull
            ?.summary
            .firstName ??
        '—';
    setState(() => _busy = true);
    final result = await ref.read(familyActionsProvider).revoke(
          RevokeGuardianshipParams(
            guardianshipId: guardianshipId,
            removedByPrimary: removedByPrimary,
          ),
        );
    if (!mounted) return;
    setState(() => _busy = false);

    result.fold(
      (failure) => _toast(familyErrorMessage(failure), isError: true),
      (revoked) {
        // Si por algún camino se estaba actuando por este menor, se sale: ya no
        // hay tutoría sobre la que actuar.
        if (leaving &&
            ref.read(actingDependentProvider)?.userId == widget.dependentId) {
          ref.read(authNotifierProvider.notifier).switchProfile(null);
        }
        if (leaving) {
          _toast(outcomeMessage(revoked.outcome, name));
          context.pop();
        } else {
          ref.invalidate(dependentDetailProvider(widget.dependentId));
          _toast('family.detail.removed'.tr());
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final detail = ref.watch(dependentDetailProvider(widget.dependentId));

    return Scaffold(
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'family.detail.title'.tr(),
        backgroundColor: c.background,
        foregroundColor: c.text,
      ),
      body: detail.when(
        loading: () => const Center(child: SacLoading()),
        error: (error, _) => _DetailError(
          error: error,
          onRetry: () =>
              ref.invalidate(dependentDetailProvider(widget.dependentId)),
        ),
        data: (data) => _Body(
          detail: data,
          busy: _busy,
          picker: widget.picker,
          onUploadForm: _uploadForm,
          onFormUploaded: _onFormUploaded,
          onViewForm: _viewForm,
          onViewAs: () => switchToDependent(context, ref, data.summary),
          onInvite: () => _invite(data),
          onLeave: (me) => _leave(data, me),
          onRemove: _remove,
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.detail,
    required this.busy,
    required this.picker,
    required this.onUploadForm,
    required this.onFormUploaded,
    required this.onViewForm,
    required this.onViewAs,
    required this.onInvite,
    required this.onLeave,
    required this.onRemove,
  });

  final DependentDetail detail;
  final bool busy;
  final ConsentEvidencePicker picker;
  final ConsentUploadCallback onUploadForm;
  final ValueChanged<ConsentEvidenceReceipt> onFormUploaded;
  final VoidCallback onViewForm;
  final VoidCallback onViewAs;
  final VoidCallback onInvite;
  final void Function(DependentGuardian me) onLeave;
  final void Function(DependentGuardian other) onRemove;

  DependentGuardian? get _me {
    for (final guardian in detail.guardians) {
      if (guardian.isMe) return guardian;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    final hPad = Responsive.horizontalPadding(context);
    final summary = detail.summary;
    final me = _me;
    final iAmPrimary = me?.isPrimary ?? false;

    return ListView(
      padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 32),
      children: [
        SacCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  DependentAvatar(
                    name: summary.firstName,
                    imageUrl: summary.userImage,
                    size: 56,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.fullName,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: c.text,
                          ),
                        ),
                        if (summary.age != null)
                          Text(
                            'family.card.age'.tr(
                              namedArgs: {'age': '${summary.age}'},
                            ),
                            style: textTheme.bodySmall?.copyWith(
                              color: c.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (summary.frozen)
                    SacBadge.error(label: 'family.frozen'.tr())
                  else
                    ConsentBadge(status: summary.guardianship.consentStatus),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                summary.frozen
                    ? 'family.frozen_hint'.tr()
                    : dependentClubLabel(summary.clubMembership),
                style: textTheme.bodySmall?.copyWith(color: c.textSecondary),
              ),
              if (!summary.frozen) ...[
                const SizedBox(height: 12),
                Text(
                  _consentText(summary.guardianship),
                  style: textTheme.bodyMedium?.copyWith(color: c.text),
                ),
              ],
            ],
          ),
        ),
        if (!summary.frozen) ...[
          const SizedBox(height: 20),
          _ConsentFormCard(
            guardianship: summary.guardianship,
            busy: busy,
            picker: picker,
            onUpload: onUploadForm,
            onUploaded: onFormUploaded,
            onView: onViewForm,
          ),
        ],
        const SizedBox(height: 20),
        _SectionLabel(label: 'family.detail.guardians'.tr()),
        const SizedBox(height: 8),
        for (final guardian in detail.guardians)
          _GuardianTile(
            guardian: guardian,
            canRemove: iAmPrimary &&
                !guardian.isMe &&
                !guardian.isCustodian &&
                guardian.userId != null,
            busy: busy,
            onRemove: () => onRemove(guardian),
          ),
        const SizedBox(height: 20),
        if (!summary.frozen) ...[
          SacButton.primary(
            text: 'family.card.view_as'.tr(
              namedArgs: {'name': summary.firstName},
            ),
            icon: HugeIcons.strokeRoundedUserSwitch,
            onPressed: busy ? null : onViewAs,
          ),
          const SizedBox(height: 12),
          SacButton.outline(
            text: 'family.detail.invite'.tr(),
            icon: HugeIcons.strokeRoundedUserAdd01,
            isLoading: busy,
            onPressed: onInvite,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'family.detail.invite_hint'.tr(),
              style: textTheme.bodySmall?.copyWith(color: c.textSecondary),
            ),
          ),
        ],
        if (me != null) ...[
          const SizedBox(height: 24),
          SacButton.destructive(
            text: 'family.detail.leave'.tr(),
            icon: HugeIcons.strokeRoundedLogout02,
            onPressed: busy ? null : () => onLeave(me),
          ),
        ],
      ],
    );
  }

  String _consentText(DependentGuardianship guardianship) {
    if (guardianship.isVerified) return 'family.detail.consent_verified'.tr();
    return guardianship.evidenceUploaded
        ? 'family.detail.consent_form_uploaded'.tr()
        : 'family.detail.consent_pending'.tr();
  }
}

/// Ficha de consentimiento firmada (FP-78).
///
/// El tutor puede subirla (foto, imagen o PDF) mientras el consentimiento está
/// pendiente; NUNCA queda verificado por subirla: eso lo hace el director. Una
/// vez verificado, solo se puede ver.
class _ConsentFormCard extends StatelessWidget {
  const _ConsentFormCard({
    required this.guardianship,
    required this.busy,
    required this.picker,
    required this.onUpload,
    required this.onUploaded,
    required this.onView,
  });

  final DependentGuardianship guardianship;
  final bool busy;
  final ConsentEvidencePicker picker;
  final ConsentUploadCallback onUpload;
  final ValueChanged<ConsentEvidenceReceipt> onUploaded;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;

    return SacCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'family.detail.form_title'.tr(),
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
          if (!guardianship.isVerified) ...[
            const SizedBox(height: 4),
            Text(
              'family.detail.form_hint'.tr(),
              style: textTheme.bodySmall?.copyWith(color: c.textSecondary),
            ),
          ],
          if (guardianship.evidenceUploaded) ...[
            const SizedBox(height: 12),
            SacButton.outline(
              text: 'family.detail.form_view'.tr(),
              icon: HugeIcons.strokeRoundedView,
              onPressed: busy ? null : onView,
            ),
          ],
          if (!guardianship.isVerified) ...[
            const SizedBox(height: 12),
            ConsentEvidenceUploader(
              picker: picker,
              hasExisting: guardianship.evidenceUploaded,
              enabled: !busy,
              onUpload: onUpload,
              onUploaded: onUploaded,
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: context.sac.textSecondary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
    );
  }
}

class _GuardianTile extends StatelessWidget {
  const _GuardianTile({
    required this.guardian,
    required this.canRemove,
    required this.busy,
    required this.onRemove,
  });

  final DependentGuardian guardian;
  final bool canRemove;
  final bool busy;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;

    return SacCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      guardian.displayName,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                    ),
                    if (guardian.relationshipTypeName != null)
                      Text(
                        guardian.relationshipTypeName!,
                        style: textTheme.bodySmall?.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              ConsentBadge(status: guardian.consentStatus),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (guardian.isMe)
                SacBadge(label: 'family.detail.you'.tr())
              else if (guardian.isCustodian)
                SacBadge(
                  label: 'family.detail.custodian'.tr(),
                  variant: SacBadgeVariant.neutral,
                ),
              if (guardian.isPrimary)
                SacBadge(
                  label: 'family.detail.primary'.tr(),
                  variant: SacBadgeVariant.neutral,
                ),
            ],
          ),
          if (canRemove) ...[
            const SizedBox(height: 8),
            SacButton.ghost(
              text: 'family.detail.remove'.tr(
                namedArgs: {'name': guardian.displayName},
              ),
              icon: HugeIcons.strokeRoundedDelete02,
              textColor: AppColors.error,
              onPressed: busy ? null : onRemove,
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final notFound = error is Failure &&
        (error as Failure).errorCode == 'GUARDIANSHIP_NOT_FOUND';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              familyErrorMessage(error),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.sac.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (notFound)
              SacButton.outline(
                text: 'common.back'.tr(),
                onPressed: () => context.pop(),
              )
            else
              SacButton.outline(text: 'common.retry'.tr(), onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
