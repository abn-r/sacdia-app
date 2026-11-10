import 'package:dartz/dartz.dart' show Either;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/consent/consent_error_messages.dart';
import '../../../../core/consent/consent_evidence.dart';
import '../../../../core/consent/consent_evidence_uploader.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../domain/entities/join_request.dart';
import '../../domain/usecases/upload_consent_evidence.dart';
import '../../domain/usecases/verify_consent.dart';
import '../providers/members_providers.dart';
import '../widgets/claim_code_section.dart';
import '../widgets/consent_verification_sections.dart';

/// Verificación del consentimiento de un menor que pide entrar al club
/// (FP-76, FP-77).
///
/// El director revisa la ficha firmada en papel (subida por el tutor o por él:
/// foto, imagen de galería o PDF), marca "Verifiqué la ficha firmada" y confirma.
/// Confirmar llama a `verify-consent` con `approve: true`. Subir una ficha o
/// salir de la pantalla NUNCA verifica.
///
/// Cuatro ojos (FP3-62): el servidor dice si quien consulta puede verificar
/// (`consent.viewer_verify_block`: `self_custodian` o `self_guardian`) y
/// "Confirmar" queda desactivado con el aviso que corresponde. Si el servidor no
/// informa el veredicto, o la ficha la subió este usuario en esta sesión, se usa
/// lo que sabe la sesión (menor bajo custodia que registró o cuya ficha subió).
/// El servidor sigue siendo la autoridad (403
/// `GUARDIANSHIP_CUSTODIAN_SELF_VERIFY` / `GUARDIANSHIP_GUARDIAN_SELF_VERIFY`). Quien solo puede verificar (sin
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

  /// La ficha ya no está pendiente y la pantalla se está cerrando.
  bool _gone = false;

  String get _assignmentId => widget.request.assignmentId;

  bool get _consentVerified => _approveError != null;

  /// Solo verifica: sin `club_members:approve` (de entrada o por el 403).
  bool get _verifyOnly => !widget.canApprove || _approveDenied;

  /// Motivo por el que el SERVIDOR impide verificar a este usuario (cuatro ojos),
  /// calculado con la misma regla que `verify-consent`. `null` si no lo impide,
  /// si no había nada que verificar al cargar la lista o si el servidor no lo
  /// informa.
  ConsentVerifyBlock? get _serverBlock =>
      widget.request.consent?.viewerVerifyBlock;

  /// Custodia del club y este usuario la registró o subió la ficha EN ESTA
  /// SESIÓN. Complementa al servidor: su dato es una foto del momento en que se
  /// cargó la lista (sin ficha, o antes de que este usuario subiera la suya) y
  /// cuando no informa el veredicto es lo único que se sabe. Solo una ayuda de
  /// interfaz: el servidor decide.
  bool get _sessionMustBeAnotherPerson {
    if (!(widget.request.consent?.isCustody ?? false)) return false;
    final userId = widget.request.userId;
    // `read`: la vista se reconstruye porque `build` vigila los dos conjuntos.
    return ref.read(createdMinorUserIdsProvider).contains(userId) ||
        ref.read(uploadedFormMinorUserIdsProvider).contains(userId);
  }

  /// "Confirmar" queda desactivado: otra persona debe verificar.
  bool get _mustBeAnotherPerson =>
      _serverBlock != null || _sessionMustBeAnotherPerson;

  /// Aviso del cuatro ojos según el motivo; `null` si no aplica.
  String? get _fourEyesNotice {
    if (_serverBlock == ConsentVerifyBlock.selfGuardian) {
      return 'errors.guardianship_guardian_self_verify'.tr();
    }
    return _mustBeAnotherPerson ? 'members.consent.another_person'.tr() : null;
  }

  /// Menor bajo custodia del club y quien consulta puede aprobar: el director
  /// puede devolverlo a su familia con un código. El servidor exige
  /// `club_members:approve`.
  bool get _canHandOff =>
      (widget.request.consent?.isCustody ?? false) &&
      widget.canApprove &&
      widget.request.clubSectionId != null;

  /// La ficha está subida y no hay nada en curso: se puede marcar "revisada".
  bool get _canReview => _hasEvidence && !_pendingFile && !_verifying;

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
    setState(() {
      _hasEvidence = true;
      _error = null;
    });
    _toast('members.consent.evidence_uploaded_toast'.tr());
  }

  /// 404 `MR_NOT_FOUND` a quien solo verifica: la ficha dejó de estar en su
  /// lista (otra persona la verificó, se aprobó, se rechazó o el menor ya no
  /// espera verificación). Se avisa y se sale con `false`: la lista de
  /// solicitudes se refresca y la cola del coordinador la quita.
  void _dropNotPending() {
    if (_gone || !mounted) return;
    _gone = true;
    _toast('members.consent.no_longer_pending'.tr(), isError: true);
    Navigator.of(context).pop(false);
  }

  void _onAlreadyVerified() {
    // La ficha vigente y la lista cambiaron: se vuelven a pedir.
    ref.invalidate(joinRequestConsentEvidenceProvider(_assignmentId));
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
        if (_verifyOnly && isRequestNotFound(failure)) {
          _dropNotPending();
          return;
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
          if (isApprovePermissionRequired(failure)) {
            _approveDenied = true;
            // Sin permiso para aprobar tampoco hay subida: un archivo elegido
            // y sin subir ya no bloquea la verificación.
            _pendingFile = false;
          }
        });
      },
      (verification) {
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

    // Subir, o la nota que la reemplaza. Nada si el consentimiento ya quedó
    // verificado.
    final Widget? evidenceActions;
    if (_verifyOnly) {
      // Subir o reemplazar la ficha exige `club_members:approve` (403 en el
      // servidor): quien solo verifica la revisa, no la sube.
      evidenceActions =
          ConsentNote('members.consent.verify_only_upload_note'.tr());
    } else if (_formAlreadyVerified) {
      evidenceActions =
          ConsentNote('errors.guardianship_consent_already_verified'.tr());
    } else if (!_consentVerified) {
      evidenceActions = ConsentEvidenceUploader(
        picker: widget.picker,
        hasExisting: _hasEvidence,
        enabled: !_verifying,
        onUpload: _upload,
        onUploaded: _onUploaded,
        onAlreadyVerified: _onAlreadyVerified,
        onPendingChanged: (pending) {
          if (mounted) setState(() => _pendingFile = pending);
        },
      );
    } else {
      evidenceActions = null;
    }

    return Scaffold(
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'members.consent.title'.tr(),
        backgroundColor: c.background,
        foregroundColor: c.text,
      ),
      bottomNavigationBar: ConsentBottomBar(
        label: _verifyOnly
            ? 'members.consent.verify_only_confirm'.tr()
            : 'members.consent.confirm'.tr(),
        retryLabel: 'members.consent.retry_approve'.tr(),
        busy: _verifying,
        onPressed:
            _consentVerified ? _confirm : (_canConfirm ? _confirm : null),
        notice: _fourEyesNotice,
        helper: _pendingFile
            ? 'members.consent.upload_first'.tr()
            : (_hasEvidence ? null : 'members.consent.upload_required'.tr()),
        error: _error,
        approvalFailedReason:
            _consentVerified ? _reasonFor(_approveError!) : null,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 24),
        children: [
          ConsentHeader(
            request: widget.request,
            verified: _consentVerified,
            verifyOnly: _verifyOnly,
          ),
          const SizedBox(height: 24),
          ConsentChecklist(
            assignmentId: _assignmentId,
            hasEvidence: _hasEvidence,
            pendingFile: _pendingFile,
            reviewed: _reviewed,
            reviewEnabled: _canReview,
            onToggleReviewed: () => setState(() => _reviewed = !_reviewed),
            confirmed: _consentVerified,
            verifyOnly: _verifyOnly,
          ),
          const SizedBox(height: 24),
          ConsentGuardiansSection(
            consent: widget.request.consent,
            // Menor bajo custodia del club: se entrega a la familia con un
            // código (fila dentro del grupo de tutores).
            handoff: _canHandOff
                ? ClaimCodeSection(
                    clubSectionId: widget.request.clubSectionId!,
                    dependentUserId: widget.request.userId,
                    dependentName: widget.request.name,
                  )
                : null,
          ),
          ConsentSectionLabel('members.consent.evidence_title'.tr()),
          const SizedBox(height: 8),
          if (_hasEvidence) ...[
            ConsentCurrentEvidence(
              assignmentId: _assignmentId,
              title: 'members.consent.evidence_title'.tr(),
              onRequestGone: _verifyOnly ? _dropNotPending : null,
            ),
            if (evidenceActions != null) ...[
              const SizedBox(height: 12),
              evidenceActions,
            ],
          ] else
            ConsentEmptyEvidence(child: evidenceActions),
        ],
      ),
    );
  }
}
