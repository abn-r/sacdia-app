import 'package:dartz/dartz.dart' show Either;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/consent/consent_error_messages.dart';
import '../../../../core/consent/consent_evidence.dart';
import '../../../../core/consent/consent_evidence_uploader.dart';
import '../../../../core/consent/consent_evidence_viewer.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/sac_badge.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_frosted_footer.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../../auth/presentation/providers/acting_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/dependent.dart';
import '../../domain/entities/supervised_login.dart';
import '../../domain/usecases/manage_supervised_login.dart';
import '../../domain/usecases/revoke_guardianship.dart';
import '../family_error_messages.dart';
import '../family_outcome_messages.dart';
import '../providers/family_providers.dart';
import '../widgets/access_section.dart';
import '../widgets/dependent_avatar.dart';
import '../../../../core/widgets/sac_list_row.dart';
import '../widgets/family_row.dart';
import '../widgets/family_sheets.dart';
import '../widgets/devices_section.dart';
import '../widgets/new_password_dialog.dart';
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

    return showFamilyCodeSheet(
      context,
      title: 'family.detail.code_title'.tr(),
      subtitle: 'family.detail.code_subtitle'.tr(),
      code: issued.code,
      expiresLabel:
          'family.detail.code_expires'.tr(namedArgs: {'when': expires}),
      onShare: () => SharePlus.instance.share(ShareParams(text: message)),
      onCopied: () => _toast('family.detail.copied'.tr()),
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

  /// El director verificó mientras el tutor subía: se explica y el detalle ya se
  /// refrescó (la tarjeta pasa a "verificado", sin subir).
  void _onFormAlreadyVerified() {
    _toast(
      'errors.guardianship_consent_already_verified'.tr(),
      isError: true,
    );
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

  // ── Acceso propio del menor (FP3-33) ────────────────────────────────────────

  void _openWizard() => context.push(
        RouteNames.familyTeenLoginPath(widget.dependentId),
      );

  void _openSummary() => context.push(
        RouteNames.familySummaryPath(widget.dependentId),
      );

  Future<void> _copyHandle(String handle) async {
    await Clipboard.setData(ClipboardData(text: handle));
    _toast('family.access.copied'.tr());
  }

  Future<void> _disableAccess(DependentSummary dependent) async {
    final name = dependent.firstName;
    final confirmed = await showFamilyConfirmSheet(
      context,
      title: 'family.access.disable_title'.tr(namedArgs: {'name': name}),
      body: 'family.access.disable_body'.tr(namedArgs: {'name': name}),
      confirmLabel: 'family.access.disable_confirm'.tr(),
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    final result = await ref.read(familyActionsProvider).disableSupervisedLogin(
          DisableSupervisedLoginParams(dependentId: widget.dependentId),
        );
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold(
      (failure) => _toast(familyErrorMessage(failure), isError: true),
      (_) => _toast('family.access.disabled_toast'.tr()),
    );
  }

  /// Reactivar: un acceso por usuario exige una contraseña NUEVA del tutor (la
  /// anterior deja de servir); uno por correo solo pide confirmar.
  Future<void> _reactivateAccess(DependentSummary dependent) async {
    final name = dependent.firstName;
    final isHandle =
        (dependent.supervisedLogin?.method ?? SupervisedLoginMethod.handle) ==
            SupervisedLoginMethod.handle;

    String? password;
    if (isHandle) {
      password = await showNewPasswordDialog(
        context,
        title: 'family.access.reactivate_title'.tr(namedArgs: {'name': name}),
        body: 'family.access.reactivate_body_handle'.tr(),
        confirmLabel: 'family.access.reactivate_confirm'.tr(),
      );
      if (password == null || !mounted) return;
    } else {
      final confirmed = await showFamilyConfirmSheet(
        context,
        title: 'family.access.reactivate_title'.tr(namedArgs: {'name': name}),
        body:
            'family.access.reactivate_body_email'.tr(namedArgs: {'name': name}),
        confirmLabel: 'family.access.reactivate_confirm'.tr(),
      );
      if (!confirmed || !mounted) return;
    }

    setState(() => _busy = true);
    final result =
        await ref.read(familyActionsProvider).reactivateSupervisedLogin(
              ReactivateSupervisedLoginParams(
                dependentId: widget.dependentId,
                password: password,
              ),
            );
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold(
      (failure) => _toast(familyErrorMessage(failure), isError: true),
      (_) => _toast('family.access.reactivated_toast'.tr()),
    );
  }

  /// Restablecer: usuario → el tutor fija una contraseña; correo → se cierran
  /// las sesiones y el menor recibe el correo estándar (el tutor nunca ve ni
  /// fija la contraseña).
  Future<void> _resetAccessPassword(DependentSummary dependent) async {
    final name = dependent.firstName;
    final isHandle =
        (dependent.supervisedLogin?.method ?? SupervisedLoginMethod.handle) ==
            SupervisedLoginMethod.handle;

    String? password;
    if (isHandle) {
      password = await showNewPasswordDialog(
        context,
        title: 'family.access.reset_title'.tr(namedArgs: {'name': name}),
        body: 'family.access.reset_body_handle'.tr(),
        confirmLabel: 'family.access.reset_confirm'.tr(),
      );
      if (password == null || !mounted) return;
    } else {
      final confirmed = await showFamilyConfirmSheet(
        context,
        title: 'family.access.reset_title'.tr(namedArgs: {'name': name}),
        body: 'family.access.reset_body_email'.tr(namedArgs: {'name': name}),
        confirmLabel: 'family.access.reset_confirm'.tr(),
        destructive: true,
      );
      if (!confirmed || !mounted) return;
    }

    setState(() => _busy = true);
    final result =
        await ref.read(familyActionsProvider).resetSupervisedPassword(
              ResetSupervisedPasswordParams(
                dependentId: widget.dependentId,
                password: password,
              ),
            );
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold(
      (failure) => _toast(familyErrorMessage(failure), isError: true),
      (reset) => _toast(
        (isHandle
                ? 'family.access.reset_toast'
                : 'family.access.reset_toast_email')
            .tr(namedArgs: {
          'count': '${reset.sessionsRevoked}',
          'name': name,
        }),
      ),
    );
  }

  Future<void> _leave(DependentDetail detail, DependentGuardian me) async {
    final name = detail.summary.firstName;
    final confirmed = await showFamilyConfirmSheet(
      context,
      title: 'family.detail.leave_title'.tr(namedArgs: {'name': name}),
      body: outcomeMessage(predictLeaveOutcome(detail), name),
      confirmLabel: 'family.detail.leave_confirm'.tr(),
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _revoke(me.guardianshipId, removedByPrimary: false, leaving: true);
  }

  Future<void> _remove(DependentGuardian other) async {
    final confirmed = await showFamilyConfirmSheet(
      context,
      title: 'family.detail.remove_title'.tr(
        namedArgs: {'name': other.displayName},
      ),
      body: 'family.detail.remove_body'.tr(),
      confirmLabel: 'family.detail.remove_confirm'.tr(),
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _revoke(other.guardianshipId, removedByPrimary: true, leaving: false);
  }

  Future<void> _revoke(
    String guardianshipId, {
    required bool removedByPrimary,
    required bool leaving,
  }) async {
    final name = ref
            .read(dependentDetailProvider(widget.dependentId))
            .value
            ?.summary
            .firstName ??
        '—';
    // El mensajero raíz sobrevive a la pantalla: tras salir se hace pop() y este
    // contexto deja de estar montado.
    final messenger = ScaffoldMessenger.of(context);
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
          // Confirmación + lo que pasará con el menor, en un solo aviso. Se
          // muestra después del pop() con el mensajero capturado, para que lo
          // vea la pantalla a la que se vuelve.
          final left = 'family.detail.left'.tr(namedArgs: {'name': name});
          final message = '$left ${outcomeMessage(revoked.outcome, name)}';
          context.pop();
          SacSnackBar.showMessenger(messenger, message);
        } else {
          ref.invalidate(dependentDetailProvider(widget.dependentId));
          _toast('family.detail.removed'.tr());
        }
      },
    );
  }

  /// Tirar para refrescar: el director pudo verificar el consentimiento (o el
  /// otro tutor cambiar algo) con la pantalla abierta. Se vuelve a pedir el
  /// detalle y la lista (que muestra el mismo estado); un fallo lo muestra el
  /// propio estado de error con "Reintentar".
  Future<void> _refresh() async {
    ref.invalidate(dependentsProvider);
    ref.invalidate(dependentDetailProvider(widget.dependentId));
    await ref
        .read(dependentDetailProvider(widget.dependentId).future)
        .then<void>((_) {}, onError: (_) {});
  }

  /// "Ver como Ana", fixed at the bottom: the one main action of the screen.
  /// Not for a frozen minor or one with their own active login (the server
  /// no longer lets the guardian act for them).
  Widget? _viewAsFooter(DependentDetail? detail) {
    final summary = detail?.summary;
    if (summary == null || summary.frozen || summary.hasActiveOwnLogin) {
      return null;
    }
    return SacFrostedFooter(
      child: SacButton.primary(
        key: const ValueKey('family-detail-view-as'),
        text: 'family.card.view_as'.tr(
          namedArgs: {'name': summary.firstName},
        ),
        icon: HugeIcons.strokeRoundedUserSwitch,
        onPressed:
            _busy ? null : () => switchToDependent(context, ref, summary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final detail = ref.watch(dependentDetailProvider(widget.dependentId));
    // La gestión del acceso propio la apaga el servidor con una bandera.
    final teenLoginEnabled = ref.watch(
      authNotifierProvider.select(
        (v) => v.value?.familyFeatures?.teenLogin ?? false,
      ),
    );

    // Vincular teléfonos de menores: la apaga el servidor con otra bandera.
    // Desconocida cuenta como apagada.
    final linkedDeviceEnabled = ref.watch(
      authNotifierProvider.select(
        (v) => v.value?.familyFeatures?.linkedDevice ?? false,
      ),
    );

    return Scaffold(
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'family.detail.title'.tr(),
        backgroundColor: c.background,
        foregroundColor: c.text,
      ),
      bottomNavigationBar: _viewAsFooter(detail.value),
      body: detail.when(
        loading: () => const Center(child: SacLoading()),
        error: (error, _) => _DetailError(
          error: error,
          onRetry: () =>
              ref.invalidate(dependentDetailProvider(widget.dependentId)),
        ),
        data: (data) => RefreshIndicator(
          color: SacAccent.of(context).color,
          onRefresh: _refresh,
          child: _Body(
            detail: data,
            busy: _busy,
            picker: widget.picker,
            onUploadForm: _uploadForm,
            onFormUploaded: _onFormUploaded,
            onFormAlreadyVerified: _onFormAlreadyVerified,
            onViewForm: _viewForm,
            teenLoginEnabled: teenLoginEnabled,
            linkedDeviceEnabled: linkedDeviceEnabled,
            onPairDevice: () => context.push(
              RouteNames.familyPairDevicePath(widget.dependentId),
            ),
            onEnableAccess: _openWizard,
            onDisableAccess: () => _disableAccess(data.summary),
            onReactivateAccess: () => _reactivateAccess(data.summary),
            onResetPassword: () => _resetAccessPassword(data.summary),
            onOpenSummary: _openSummary,
            onCopyHandle: _copyHandle,
            onInvite: () => _invite(data),
            onLeave: (me) => _leave(data, me),
            onRemove: _remove,
          ),
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
    required this.onFormAlreadyVerified,
    required this.onViewForm,
    required this.teenLoginEnabled,
    required this.linkedDeviceEnabled,
    required this.onPairDevice,
    required this.onEnableAccess,
    required this.onDisableAccess,
    required this.onReactivateAccess,
    required this.onResetPassword,
    required this.onOpenSummary,
    required this.onCopyHandle,
    required this.onInvite,
    required this.onLeave,
    required this.onRemove,
  });

  final DependentDetail detail;
  final bool busy;
  final ConsentEvidencePicker picker;
  final ConsentUploadCallback onUploadForm;
  final ValueChanged<ConsentEvidenceReceipt> onFormUploaded;
  final VoidCallback onFormAlreadyVerified;
  final VoidCallback onViewForm;
  final bool teenLoginEnabled;
  final bool linkedDeviceEnabled;
  final VoidCallback onPairDevice;
  final VoidCallback onEnableAccess;
  final VoidCallback onDisableAccess;
  final VoidCallback onReactivateAccess;
  final VoidCallback onResetPassword;
  final VoidCallback onOpenSummary;
  final ValueChanged<String> onCopyHandle;
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
    final hPad = Responsive.horizontalPadding(context);
    final summary = detail.summary;
    final me = _me;
    final iAmPrimary = me?.isPrimary ?? false;

    return ListView(
      // Siempre desplazable: con poco contenido el gesto de refrescar debe
      // seguir funcionando.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _Identity(summary: summary),
        if (!summary.frozen) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 0),
            child: _ConsentPanel(guardianship: summary.guardianship),
          ),
          if (!summary.guardianship.isVerified ||
              summary.guardianship.evidenceUploaded)
            _ConsentFormCard(
              guardianship: summary.guardianship,
              busy: busy,
              picker: picker,
              onUpload: onUploadForm,
              onUploaded: onFormUploaded,
              onAlreadyVerified: onFormAlreadyVerified,
              onView: onViewForm,
            ),
          AccessSection(
            summary: summary,
            teenLoginEnabled: teenLoginEnabled,
            busy: busy,
            onEnable: onEnableAccess,
            onDisable: onDisableAccess,
            onReactivate: onReactivateAccess,
            onResetPassword: onResetPassword,
            onOpenSummary: onOpenSummary,
            onCopyHandle: onCopyHandle,
          ),
        ],
        if (shouldShowDevicesSection(
          summary,
          featureEnabled: linkedDeviceEnabled,
        ))
          DevicesSection(summary: summary, onPair: onPairDevice),
        SacGroupedSection(
          label: 'family.detail.guardians'.tr(),
          count: detail.guardians.length,
          children: [
            for (final guardian in detail.guardians) ...[
              _GuardianRow(guardian: guardian),
              if (iAmPrimary &&
                  !guardian.isMe &&
                  !guardian.isCustodian &&
                  guardian.userId != null)
                SacListRow(
                  key: ValueKey('family-remove-${guardian.guardianshipId}'),
                  leading: const SacListRowIcon(
                    HugeIcons.strokeRoundedDelete02,
                    destructive: true,
                  ),
                  title: 'family.detail.remove'.tr(
                    namedArgs: {'name': guardian.displayName},
                  ),
                  titleColor: context.sac.onErrorContainer,
                  enabled: !busy,
                  showChevron: false,
                  onTap: () => onRemove(guardian),
                ),
            ],
          ],
        ),
        if (!summary.frozen || me != null)
          Padding(
            padding: EdgeInsets.fromLTRB(hPad, 24, hPad, 0),
            child: _ActionsGroup(
              children: [
                if (!summary.frozen)
                  SacListRow(
                    key: const ValueKey('family-detail-invite'),
                    leading:
                        const SacListRowIcon(HugeIcons.strokeRoundedUserAdd01),
                    title: 'family.detail.invite'.tr(),
                    subtitle: 'family.detail.invite_hint'.tr(),
                    enabled: !busy,
                    onTap: onInvite,
                  ),
                if (me != null)
                  SacListRow(
                    key: const ValueKey('family-detail-leave'),
                    leading: const SacListRowIcon(
                      HugeIcons.strokeRoundedLogout02,
                      destructive: true,
                    ),
                    title: 'family.detail.leave'.tr(),
                    titleColor: context.sac.onErrorContainer,
                    enabled: !busy,
                    showChevron: false,
                    onTap: () => onLeave(me),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Avatar, name and the line under it (age and club, or frozen).
class _Identity extends StatelessWidget {
  const _Identity({required this.summary});

  final DependentSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final parts = <String>[
      if (summary.age != null)
        'family.card.age'.tr(namedArgs: {'age': '${summary.age}'}),
      summary.frozen
          ? 'family.frozen_hint'.tr()
          : dependentClubLabel(summary.clubMembership),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Column(
        children: [
          DependentAvatar(
            name: summary.firstName,
            imageUrl: summary.userImage,
            size: 64,
          ),
          const SizedBox(height: 10),
          Text(
            summary.fullName,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: SacFontSize.headlineMedium,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: c.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            parts.join(' · '),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: SacFontSize.bodyMedium,
              color: summary.frozen ? c.onErrorContainer : c.textSecondary,
            ),
          ),
          if (summary.frozen) ...[
            const SizedBox(height: 8),
            SacBadge.error(
              label: 'family.frozen'.tr(),
              icon: HugeIcons.strokeRoundedSnow,
            ),
          ],
        ],
      ),
    );
  }
}

/// Where the consent stands: missing form, form in review or verified. One
/// state at a time; tapping it shows the three in order.
class _ConsentPanel extends StatelessWidget {
  const _ConsentPanel({required this.guardianship});

  final DependentGuardianship guardianship;

  int get _step => guardianship.isVerified
      ? 3
      : guardianship.evidenceUploaded
          ? 2
          : 1;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final step = _step;
    final (titleKey, messageKey) = switch (step) {
      3 => ('family.consent.verified', 'family.detail.consent_verified'),
      2 => ('family.consent.in_review', 'family.detail.consent_form_uploaded'),
      _ => ('family.consent.missing', 'family.detail.consent_pending'),
    };
    final title = titleKey.tr();
    final style = switch (step) {
      3 => SacStatusStyle.of(
          context,
          SacStatusKind.validated,
          label: title,
          icon: HugeIcons.strokeRoundedCheckmarkBadge01,
        ),
      2 => SacStatusStyle.of(
          context,
          SacStatusKind.review,
          label: title,
          icon: HugeIcons.strokeRoundedClock01,
        ),
      _ => SacStatusStyle(
          kind: SacStatusKind.pending,
          container: c.warningContainer,
          onContainer: c.onWarningContainer,
          solid: c.warning,
          icon: HugeIcons.strokeRoundedFileEdit,
          label: title,
        ),
    };
    return SacStatePanel(
      key: ValueKey('family-consent-$step'),
      style: style,
      title: title,
      message: messageKey.tr(),
      stepLabel: step < 3
          ? 'family.consent.step'.tr(namedArgs: {'step': '$step', 'total': '3'})
          : null,
      semanticsHint: 'family.consent.all_states'.tr(),
      onTap: () => _showStates(context, step),
    );
  }

  void _showStates(BuildContext context, int step) {
    SacStateKind kindOf(int index) => index < step
        ? SacStateKind.done
        : index == step
            ? (step == 3 ? SacStateKind.done : SacStateKind.current)
            : SacStateKind.pending;
    showSacStatesSheet(
      context,
      title: 'family.consent.sheet_title'.tr(),
      subtitle: 'family.consent.sheet_subtitle'.tr(),
      steps: [
        SacStateStep(
          kind: kindOf(1),
          title: 'family.consent.state_upload'.tr(),
          detail: 'family.consent.state_upload_detail'.tr(),
        ),
        SacStateStep(
          kind: kindOf(2),
          title: 'family.consent.state_review'.tr(),
          detail: 'family.consent.state_review_detail'.tr(),
        ),
        SacStateStep(
          kind: kindOf(3),
          title: 'family.consent.verified'.tr(),
          detail: 'family.consent.state_verified_detail'.tr(),
        ),
      ],
      kindLabels: SacStateKindLabels(
        done: 'family.consent.kind_done'.tr(),
        current: 'family.consent.kind_current'.tr(),
        rejected: 'family.consent.kind_current'.tr(),
        pending: 'family.consent.kind_pending'.tr(),
      ),
    );
  }
}

/// A bordered card holding a few rows, without an eyebrow.
class _ActionsGroup extends StatelessWidget {
  const _ActionsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(height: 1, thickness: 1, indent: 62, color: c.divider),
            children[i],
          ],
        ],
      ),
    );
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
    required this.onAlreadyVerified,
    required this.onView,
  });

  final DependentGuardianship guardianship;
  final bool busy;
  final ConsentEvidencePicker picker;
  final ConsentUploadCallback onUpload;
  final ValueChanged<ConsentEvidenceReceipt> onUploaded;
  final VoidCallback onAlreadyVerified;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('family-consent-form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SacGroupedSection(
          label: 'family.detail.form_title'.tr(),
          action: const SizedBox.shrink(),
          dividerIndent: 62,
          children: [
            if (guardianship.evidenceUploaded)
              SacListRow(
                key: const ValueKey('family-consent-form-view'),
                leading: const SacListRowIcon(HugeIcons.strokeRoundedView),
                title: 'family.detail.form_view'.tr(),
                enabled: !busy,
                onTap: onView,
              ),
            if (!guardianship.isVerified)
              Padding(
                padding: const EdgeInsets.all(14),
                child: ConsentEvidenceUploader(
                  picker: picker,
                  hasExisting: guardianship.evidenceUploaded,
                  enabled: !busy,
                  onUpload: onUpload,
                  onUploaded: onUploaded,
                  onAlreadyVerified: onAlreadyVerified,
                ),
              ),
          ],
        ),
        if (!guardianship.isVerified)
          FamilyFootnote(text: 'family.detail.form_hint'.tr()),
      ],
    );
  }
}

/// A guardian: name, relationship and consent, with "Tú", "Principal" or
/// "Custodia del club" at the end.
class _GuardianRow extends StatelessWidget {
  const _GuardianRow({required this.guardian});

  final DependentGuardian guardian;

  @override
  Widget build(BuildContext context) {
    final verified = guardian.consentStatus == GuardianConsentStatus.verified;
    final parts = <String>[
      if (guardian.relationshipTypeName != null) guardian.relationshipTypeName!,
      verified ? 'family.consent.verified'.tr() : 'family.consent.pending'.tr(),
    ];
    return SacListRow(
      key: ValueKey('family-guardian-${guardian.guardianshipId}'),
      leading: DependentAvatar(name: guardian.displayName, size: 36),
      title: guardian.displayName,
      subtitle: parts.join(' · '),
      trailing: Wrap(
        spacing: 6,
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
