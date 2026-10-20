import 'package:dartz/dartz.dart' show Either;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

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
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../domain/entities/join_request.dart';
import '../../domain/usecases/upload_consent_evidence.dart';
import '../../domain/usecases/verify_consent.dart';
import '../providers/members_providers.dart';

/// Verificación del consentimiento de un menor que pide entrar al club
/// (FP-76, FP-77).
///
/// El director revisa la ficha firmada en papel (subida por el tutor o por él:
/// foto, imagen de galería o PDF), marca "Verifiqué la ficha firmada" y confirma.
/// Confirmar llama a `verify-consent` con `approve: true`. Subir una ficha o
/// salir de la pantalla NUNCA verifica.
///
/// Cuatro ojos (FP3-62): si el menor está bajo custodia del club y el usuario lo
/// registró o subió la ficha, "Confirmar" queda desactivado con el aviso de que
/// otra persona debe verificar. El servidor sigue siendo la autoridad (403
/// `GUARDIANSHIP_CUSTODIAN_SELF_VERIFY`). Quien solo puede verificar (sin
/// `club_members:approve`, [canApprove] falso) no ve "aprobar": verifica con
/// `approve: false`.
///
/// Se hace pop con `true` cuando la solicitud quedó aprobada y con `false` si
/// solo se verificó.
class ConsentVerificationView extends ConsumerStatefulWidget {
  const ConsentVerificationView({
    super.key,
    required this.request,
    this.canApprove = true,
    this.picker = const ConsentEvidencePicker(),
  });

  final JoinRequest request;

  /// El usuario tiene `club_members:approve`. Sin él solo puede verificar.
  final bool canApprove;

  /// Inyectable para probar sin los plugins de cámara/archivos.
  final ConsentEvidencePicker picker;

  @override
  ConsumerState<ConsentVerificationView> createState() =>
      _ConsentVerificationViewState();
}

class _ConsentVerificationViewState
    extends ConsumerState<ConsentVerificationView> {
  late bool _hasEvidence = widget.request.consent?.evidenceUploaded ?? false;

  /// Hay un archivo elegido que todavía no se subió.
  bool _pendingFile = false;
  bool _reviewed = false;

  /// El servidor rechazó una subida porque el consentimiento ya quedó verificado
  /// (409): la ficha ya no se puede reemplazar desde aquí.
  bool _formAlreadyVerified = false;
  bool _verifying = false;

  /// El servidor respondió 403 `GUARDIANSHIP_CUSTODIAN_SELF_VERIFY`: este
  /// usuario no puede verificar a este menor y reintentar no cambia nada.
  bool _custodianBlocked = false;

  /// El servidor respondió 403 `MR_APPROVE_PERMISSION_REQUIRED`: solo puede
  /// verificar, no aprobar (no se escribió nada).
  bool _approveDenied = false;

  /// El consentimiento ya quedó verificado pero la aprobación falló: solo queda
  /// reintentar la aprobación.
  String? _approveError;

  Object? _error;

  String get _assignmentId => widget.request.assignmentId;

  bool get _consentVerified => _approveError != null;

  /// Solo verifica: sin `club_members:approve` (de entrada o por el 403).
  bool get _verifyOnly => !widget.canApprove || _approveDenied;

  /// Custodia del club y este usuario la registró o subió la ficha (cuatro
  /// ojos). Solo una ayuda de interfaz: el servidor decide.
  bool get _mustBeAnotherPerson {
    if (!(widget.request.consent?.isCustody ?? false)) return false;
    final userId = widget.request.userId;
    // `read`: la vista se reconstruye porque `build` vigila los dos conjuntos.
    return ref.read(createdMinorUserIdsProvider).contains(userId) ||
        ref.read(uploadedFormMinorUserIdsProvider).contains(userId);
  }

  bool get _canConfirm =>
      _hasEvidence &&
      !_pendingFile &&
      _reviewed &&
      !_verifying &&
      !_custodianBlocked &&
      !_mustBeAnotherPerson;

  void _toast(String message, {bool isError = false}) {
    if (!mounted) return;
    SacSnackBar.show(context, message, isError: isError);
  }

  Future<Either<Failure, ConsentEvidenceReceipt>> _upload(
    ConsentEvidenceLocalFile file,
  ) {
    return ref.read(uploadConsentEvidenceUseCaseProvider)(
      UploadConsentEvidenceParams(assignmentId: _assignmentId, file: file),
    );
  }

  void _onUploaded(ConsentEvidenceReceipt receipt) {
    // Quien sube la ficha de un menor bajo custodia no puede verificarlo.
    if (widget.request.consent?.isCustody ?? false) {
      ref.read(uploadedFormMinorUserIdsProvider.notifier).update(
            (ids) => {...ids, widget.request.userId},
          );
    }
    ref.invalidate(joinRequestConsentEvidenceProvider(_assignmentId));
    // La lista de solicitudes trae `evidence_uploaded`: se refresca.
    ref.invalidate(membersNotifierProvider);
    setState(() {
      _hasEvidence = true;
      _error = null;
    });
    _toast('members.consent.evidence_uploaded_toast'.tr());
  }

  void _onAlreadyVerified() {
    // La ficha vigente y la lista cambiaron: se vuelven a pedir.
    ref.invalidate(joinRequestConsentEvidenceProvider(_assignmentId));
    ref.invalidate(membersNotifierProvider);
    setState(() {
      _formAlreadyVerified = true;
      // Si estaba verificada, hay una ficha vigente. El archivo descartado ya
      // no bloquea confirmar.
      _hasEvidence = true;
      _pendingFile = false;
      _error = null;
    });
    _toast('errors.guardianship_consent_already_verified'.tr(), isError: true);
  }

  Future<void> _confirm() async {
    if (!_canConfirm && !_consentVerified) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    final approve = !_verifyOnly;
    final result = await ref.read(verifyConsentUseCaseProvider)(
      VerifyConsentParams(assignmentId: _assignmentId, approve: approve),
    );
    if (!mounted) return;

    result.fold(
      (failure) {
        // La solicitud puede haber cambiado desde que se abrió la lista.
        if (failure.errorCode == 'MR_NOT_FOUND' ||
            failure.errorCode == 'MR_ALREADY_PENDING') {
          ref.invalidate(membersNotifierProvider);
        }
        setState(() {
          _verifying = false;
          _error = failure;
          // El servidor dice que no hay ficha vigente: volver a pedirla.
          if (failure.errorCode == 'GUARDIANSHIP_EVIDENCE_REQUIRED') {
            _hasEvidence = false;
          }
          // Cuatro ojos: otra persona debe verificar. No se vuelve a intentar.
          if (isCustodianSelfVerify(failure)) _custodianBlocked = true;
          // Sin `club_members:approve`: se queda en "solo verificar" (el 403 se
          // da antes de escribir nada).
          if (isApprovePermissionRequired(failure)) _approveDenied = true;
        });
      },
      (verification) {
        // El consentimiento ya está verificado: la lista cambia de todos modos.
        ref.invalidate(membersNotifierProvider);
        if (verification.approvalFailed) {
          setState(() {
            _verifying = false;
            _approveError = verification.approveError;
          });
          return;
        }
        if (!approve) {
          // Verificado, NO aprobado: aprobar le corresponde a un director.
          _toast(
            'members.consent.verified_toast'.tr(
              namedArgs: {'name': widget.request.fullName},
            ),
          );
          Navigator.of(context).pop(false);
          return;
        }
        _toast(
          'members.consent.approved'.tr(
            namedArgs: {'name': widget.request.fullName},
          ),
        );
        Navigator.of(context).pop(true);
      },
    );
  }

  String _reasonFor(String code) {
    final key = 'errors.${code.toLowerCase()}';
    final text = key.tr();
    return text == key ? 'core.consent.errors.generic'.tr() : text;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final hPad = Responsive.horizontalPadding(context);
    // Cuatro ojos: se reconstruye si cambia quién registró o subió la ficha.
    ref.watch(createdMinorUserIdsProvider);
    ref.watch(uploadedFormMinorUserIdsProvider);

    return Scaffold(
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'members.consent.title'.tr(),
        backgroundColor: c.background,
        foregroundColor: c.text,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 32),
        children: [
          _Intro(request: widget.request),
          const SizedBox(height: 20),
          _SectionLabel(label: 'members.consent.evidence_title'.tr()),
          const SizedBox(height: 8),
          if (_hasEvidence)
            _CurrentEvidence(
              assignmentId: _assignmentId,
              title: 'members.consent.evidence_title'.tr(),
            )
          else
            Text(
              'members.consent.evidence_none'.tr(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: c.textSecondary,
                  ),
            ),
          const SizedBox(height: 12),
          if (_formAlreadyVerified)
            Text(
              'errors.guardianship_consent_already_verified'.tr(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: c.textSecondary,
                  ),
            )
          else if (!_consentVerified)
            ConsentEvidenceUploader(
              picker: widget.picker,
              hasExisting: _hasEvidence,
              enabled: !_verifying,
              onUpload: _upload,
              onUploaded: _onUploaded,
              onAlreadyVerified: _onAlreadyVerified,
              onPendingChanged: (pending) {
                if (mounted) setState(() => _pendingFile = pending);
              },
            ),
          const SizedBox(height: 24),
          if (_consentVerified)
            _ApprovalFailed(
              reason: _reasonFor(_approveError!),
              busy: _verifying,
              error: _error,
              onRetry: _confirm,
            )
          else
            _ConfirmSection(
              verifyOnly: _verifyOnly,
              notice: _mustBeAnotherPerson
                  ? 'members.consent.another_person'.tr()
                  : null,
              reviewed: _reviewed,
              onReviewedChanged: (value) => setState(() => _reviewed = value),
              pendingFile: _pendingFile,
              busy: _verifying,
              canConfirm: _canConfirm,
              error: _error,
              onConfirm: _confirm,
            ),
        ],
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.request});

  final JoinRequest request;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    final guardians = request.consent?.guardians ?? const [];

    return SacCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            request.fullName,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            children: [
              SacBadge.warning(
                label: 'members.consent.badge_pending'.tr(),
                icon: HugeIcons.strokeRoundedClock01,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'members.consent.intro'.tr(namedArgs: {'name': request.name}),
            style: textTheme.bodyMedium?.copyWith(color: c.textSecondary),
          ),
          if (guardians.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'members.consent.guardians'.tr(),
              style: textTheme.labelMedium?.copyWith(
                color: c.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            for (final guardian in guardians)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  [
                    guardian.displayName,
                    if (guardian.relationshipTypeName != null)
                      guardian.relationshipTypeName!,
                    if (guardian.isPrimary)
                      'members.consent.guardian_primary'.tr(),
                  ].join(' · '),
                  style: textTheme.bodyMedium?.copyWith(color: c.text),
                ),
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

/// Ficha vigente con su URL firmada. La URL se pide al abrir la pantalla y no se
/// guarda en ningún caché.
class _CurrentEvidence extends ConsumerWidget {
  const _CurrentEvidence({required this.assignmentId, required this.title});

  final String assignmentId;
  final String title;

  String _uploadedLabel(BuildContext context, ConsentEvidenceAccess access) {
    final at = access.uploadedAt;
    final date = at == null
        ? null
        : DateFormat.yMMMd(context.locale.toString())
            .add_jm()
            .format(at.toLocal());
    final by = access.uploadedByDisplayName;
    if (date == null) return '';
    return by == null
        ? 'members.consent.evidence_uploaded_on'.tr(namedArgs: {'date': date})
        : 'members.consent.evidence_uploaded_by'
            .tr(namedArgs: {'name': by, 'date': date});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    final evidence =
        ref.watch(joinRequestConsentEvidenceProvider(assignmentId));

    return evidence.when(
      loading: () => Row(
        children: [
          const SacLoadingSmall(),
          const SizedBox(width: 12),
          Text(
            'members.consent.evidence_loading'.tr(),
            style: textTheme.bodyMedium?.copyWith(color: c.textSecondary),
          ),
        ],
      ),
      error: (error, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isConsentEvidenceUnavailable(error)
                ? consentErrorMessage(error)
                : 'members.consent.evidence_load_error'.tr(),
            style: textTheme.bodyMedium?.copyWith(color: AppColors.error),
          ),
          if (!isConsentEvidenceUnavailable(error))
            TextButton(
              onPressed: () => ref.invalidate(
                joinRequestConsentEvidenceProvider(assignmentId),
              ),
              child: Text('core.consent.retry'.tr()),
            ),
        ],
      ),
      data: (access) => SacCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                HugeIcon(
                  icon: access.isPdf
                      ? HugeIcons.strokeRoundedPdf01
                      : HugeIcons.strokeRoundedImage01,
                  size: 28,
                  color: c.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _uploadedLabel(context, access),
                    style: textTheme.bodySmall?.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SacButton.outline(
              text: 'members.consent.evidence_view'.tr(),
              icon: HugeIcons.strokeRoundedView,
              onPressed: () => openConsentEvidence(
                context,
                access,
                title: title,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmSection extends StatelessWidget {
  const _ConfirmSection({
    required this.verifyOnly,
    required this.notice,
    required this.reviewed,
    required this.onReviewedChanged,
    required this.pendingFile,
    required this.busy,
    required this.canConfirm,
    required this.error,
    required this.onConfirm,
  });

  /// Sin permiso para aprobar: el botón solo verifica.
  final bool verifyOnly;

  /// Aviso de cuatro ojos (otra persona debe verificar); `null` si no aplica.
  final String? notice;
  final bool reviewed;
  final ValueChanged<bool> onReviewedChanged;
  final bool pendingFile;
  final bool busy;
  final bool canConfirm;
  final Object? error;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (verifyOnly)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'members.consent.verify_only_hint'.tr(),
              style: textTheme.bodySmall?.copyWith(color: c.textSecondary),
            ),
          ),
        if (notice != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              notice!,
              style: textTheme.bodyMedium?.copyWith(color: AppColors.error),
            ),
          ),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Checkbox(
                value: reviewed,
                onChanged: busy ? null : (v) => onReviewedChanged(v ?? false),
                materialTapTargetSize: MaterialTapTargetSize.padded,
              ),
              Expanded(
                child: Text(
                  'members.consent.reviewed'.tr(),
                  style: textTheme.bodyMedium?.copyWith(color: c.text),
                ),
              ),
            ],
          ),
        ),
        if (pendingFile)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'members.consent.upload_first'.tr(),
              style: textTheme.bodySmall?.copyWith(color: c.textSecondary),
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              consentErrorMessage(error),
              style: textTheme.bodyMedium?.copyWith(color: AppColors.error),
            ),
          ),
        SacButton.primary(
          text: verifyOnly
              ? 'members.consent.verify_only_confirm'.tr()
              : 'members.consent.confirm'.tr(),
          icon: HugeIcons.strokeRoundedCheckmarkCircle01,
          isLoading: busy,
          onPressed: canConfirm ? onConfirm : null,
        ),
      ],
    );
  }
}

/// El consentimiento quedó verificado pero la aprobación falló: reintentar la
/// misma llamada solo reintenta la aprobación.
class _ApprovalFailed extends StatelessWidget {
  const _ApprovalFailed({
    required this.reason,
    required this.busy,
    required this.error,
    required this.onRetry,
  });

  final String reason;
  final bool busy;
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SacBadge.success(
          label: 'members.consent.badge_verified'.tr(),
          icon: HugeIcons.strokeRoundedCheckmarkBadge01,
        ),
        const SizedBox(height: 8),
        Text(
          'members.consent.verified_not_approved'.tr(
            namedArgs: {'reason': reason},
          ),
          style: textTheme.bodyMedium?.copyWith(color: AppColors.error),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              consentErrorMessage(error),
              style: textTheme.bodyMedium?.copyWith(color: AppColors.error),
            ),
          ),
        const SizedBox(height: 12),
        SacButton.primary(
          text: 'members.consent.retry_approve'.tr(),
          icon: HugeIcons.strokeRoundedRefresh,
          isLoading: busy,
          onPressed: busy ? null : onRetry,
        ),
      ],
    );
  }
}
