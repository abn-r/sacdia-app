import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/local/certification_draft_local_data_source.dart';
import '../../domain/entities/certification_requirement.dart';
import '../../domain/entities/certification_requirement_component.dart';
import 'certifications_providers.dart';

/// Identifica de forma única un requisito (sección) en ejecución.
///
/// `enrollmentId` conduce todas las llamadas al backend (contrato del plan
/// base: rutas `.../certification-enrollments/:enrollmentId/...`) y la clave
/// del borrador local (Hive); `certificationId` se conserva solo para
/// invalidar el provider de progreso, que sigue keyed por certificación.
class CertificationRequirementQuery extends Equatable {
  final int certificationId;
  final int sectionId;
  final int enrollmentId;

  const CertificationRequirementQuery({
    required this.certificationId,
    required this.sectionId,
    required this.enrollmentId,
  });

  @override
  List<Object?> get props => [certificationId, sectionId, enrollmentId];
}

/// Provider para la fuente de datos local de borradores de requisitos.
final certificationDraftLocalDataSourceProvider =
    Provider<CertificationDraftLocalDataSource>((ref) {
  return CertificationDraftLocalDataSource(
    ref.watch(certificationDraftBoxProvider),
  );
});

/// Estado de un requisito en ejecución: datos del backend + overlay de
/// respuestas editadas localmente (borrador) aún no confirmadas por el
/// backend.
class CertificationRequirementState extends Equatable {
  final CertificationRequirement? requirement;
  final Map<int, CertificationComponentDraftInput> localValues;
  final bool isLoading;
  final bool isSavingDraft;
  final bool isSubmitting;
  final String? errorMessage;
  final bool submitSuccess;

  /// `lock_version` optimista de la inscripción.
  ///
  /// LIMITACIÓN CONOCIDA: el endpoint participante `GET .../requirements/:id`
  /// no expone `lock_version` (solo lo hace la vista de revisor). El cliente
  /// arranca en 0 y lo incrementa localmente tras cada `submit` exitoso. Si
  /// el valor real en el backend avanza por otra vía dentro de la misma
  /// sesión, el próximo `submit` puede fallar con `CERT_CONCURRENT_UPDATE`
  /// (409) de forma espuria — requiere que el backend exponga
  /// `lock_version` en la vista de participante para resolverse por completo.
  final int lockVersion;

  const CertificationRequirementState({
    this.requirement,
    this.localValues = const {},
    this.isLoading = false,
    this.isSavingDraft = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.submitSuccess = false,
    this.lockVersion = 0,
  });

  /// Componentes del requisito con la respuesta remota fusionada con el
  /// overlay local (el overlay gana si existe una entrada para ese
  /// componente).
  List<CertificationRequirementComponent> get componentsWithLocalOverlay {
    final req = requirement;
    if (req == null) return const [];
    return req.components.map((c) {
      final draft = localValues[c.componentId];
      if (draft == null) return c;
      return CertificationRequirementComponent(
        componentId: c.componentId,
        type: c.type,
        label: c.label,
        required: c.required,
        response: CertificationComponentResponse(
          textValue: draft.textValue ?? c.response?.textValue,
          attestationConfirmed:
              draft.attestationConfirmed ?? c.response?.attestationConfirmed,
          linkedUserHonorId:
              draft.linkedUserHonorId ?? c.response?.linkedUserHonorId,
          linkedActivityId:
              draft.linkedActivityId ?? c.response?.linkedActivityId,
        ),
      );
    }).toList();
  }

  bool get hasUnsavedLocalChanges => localValues.isNotEmpty;

  CertificationRequirementState copyWith({
    CertificationRequirement? requirement,
    Map<int, CertificationComponentDraftInput>? localValues,
    bool? isLoading,
    bool? isSavingDraft,
    bool? isSubmitting,
    String? errorMessage,
    bool? submitSuccess,
    int? lockVersion,
  }) {
    return CertificationRequirementState(
      requirement: requirement ?? this.requirement,
      localValues: localValues ?? this.localValues,
      isLoading: isLoading ?? this.isLoading,
      isSavingDraft: isSavingDraft ?? this.isSavingDraft,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
      submitSuccess: submitSuccess ?? false,
      lockVersion: lockVersion ?? this.lockVersion,
    );
  }

  @override
  List<Object?> get props => [
        requirement,
        localValues,
        isLoading,
        isSavingDraft,
        isSubmitting,
        errorMessage,
        submitSuccess,
        lockVersion,
      ];
}

/// Notifier que orquesta la ejecución de un requisito: carga inicial (con
/// restauración de borrador local), edición de componentes, guardado de
/// borrador remoto, envío a revisión y evidencias de archivo.
class CertificationRequirementNotifier extends AutoDisposeFamilyNotifier<
    CertificationRequirementState, CertificationRequirementQuery> {
  @override
  CertificationRequirementState build(CertificationRequirementQuery query) {
    Future.microtask(_load);
    return const CertificationRequirementState(isLoading: true);
  }

  CertificationRequirementQuery get _query => arg;

  String get _userId {
    final authState = ref.read(authNotifierProvider);
    return authState.value?.id ?? '';
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final result =
        await ref.read(certificationsRepositoryProvider).getRequirement(
              _userId,
              _query.enrollmentId,
              _query.sectionId,
            );

    result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
      },
      (requirement) {
        final localDraft = requirement.canEdit
            ? ref
                .read(certificationDraftLocalDataSourceProvider)
                .getDraft(_query.enrollmentId, _query.sectionId)
            : null;
        state = state.copyWith(
          isLoading: false,
          requirement: requirement,
          localValues: localDraft ?? const {},
        );
      },
    );
  }

  Future<void> reload() => _load();

  /// Actualiza (en memoria + Hive) la respuesta de un componente. Reemplaza
  /// cualquier valor previo para ese `componentId` — el llamador debe pasar
  /// el conjunto completo de campos relevantes al tipo de componente.
  void updateComponentValue(CertificationComponentDraftInput input) {
    final updated = Map<int, CertificationComponentDraftInput>.from(
      state.localValues,
    );
    updated[input.componentId] = input;
    state = state.copyWith(localValues: updated);
    // Persistimos en Hive de inmediato: son ediciones de texto/checkbox de
    // baja frecuencia comparadas con, p.ej., progreso de subida de archivo.
    unawaited(
      ref
          .read(certificationDraftLocalDataSourceProvider)
          .saveDraft(_query.enrollmentId, _query.sectionId, updated),
    );
  }

  /// Guarda el borrador actual en el backend. Al confirmarse, limpia el
  /// borrador local (ya quedó persistido remotamente).
  Future<bool> saveDraft() async {
    if (state.localValues.isEmpty) return true;
    state = state.copyWith(isSavingDraft: true, errorMessage: null);

    final result =
        await ref.read(certificationsRepositoryProvider).saveRequirementDraft(
              _userId,
              _query.enrollmentId,
              _query.sectionId,
              state.localValues.values.toList(),
            );

    return result.fold(
      (failure) {
        state =
            state.copyWith(isSavingDraft: false, errorMessage: failure.message);
        return false;
      },
      (requirement) {
        state = state.copyWith(
          isSavingDraft: false,
          requirement: requirement,
          localValues: const {},
        );
        unawaited(
          ref
              .read(certificationDraftLocalDataSourceProvider)
              .clearDraft(_query.enrollmentId, _query.sectionId),
        );
        return true;
      },
    );
  }

  /// Envía el requisito a revisión. Si hay cambios locales sin guardar, los
  /// guarda primero para no perder respuestas capturadas justo antes del
  /// envío.
  Future<bool> submit() async {
    if (state.localValues.isNotEmpty) {
      final saved = await saveDraft();
      if (!saved) return false;
    }

    state = state.copyWith(
        isSubmitting: true, errorMessage: null, submitSuccess: false);

    final result =
        await ref.read(certificationsRepositoryProvider).submitRequirement(
              _userId,
              _query.enrollmentId,
              _query.sectionId,
              lockVersion: state.lockVersion,
            );

    return result.fold(
      (failure) {
        state =
            state.copyWith(isSubmitting: false, errorMessage: failure.message);
        return false;
      },
      (submitResult) {
        state = state.copyWith(
          isSubmitting: false,
          requirement: submitResult.requirement,
          localValues: const {},
          submitSuccess: true,
          lockVersion: state.lockVersion + 1,
        );
        unawaited(
          ref
              .read(certificationDraftLocalDataSourceProvider)
              .clearDraft(_query.enrollmentId, _query.sectionId),
        );
        ref.invalidate(certificationProgressProvider(_query.certificationId));
        return true;
      },
    );
  }

  /// Sube una evidencia para un componente `FILE_EVIDENCE`: presign → PUT
  /// directo a R2 → confirm. Lanza en caso de error, tal como espera
  /// `EvidenceStagingManager.onUpload`.
  Future<void> uploadComponentEvidence({
    required int componentId,
    required String filePath,
    required String fileName,
    required String mimeType,
    required int fileSize,
    required void Function(double progress) onProgress,
  }) async {
    final repo = ref.read(certificationsRepositoryProvider);

    final presignResult = await repo.presignRequirementEvidence(
      _userId,
      _query.enrollmentId,
      _query.sectionId,
      componentId: componentId,
      fileName: fileName,
      mimeType: mimeType,
      fileSize: fileSize,
    );

    final ticket = presignResult.fold(
      (failure) => throw Exception(failure.message),
      (ticket) => ticket,
    );

    final uploadResult = await repo.uploadEvidenceFile(
      uploadUrl: ticket.uploadUrl,
      filePath: filePath,
      mimeType: mimeType,
      headers: ticket.requiredHeaders,
      onProgress: onProgress,
    );

    uploadResult.fold(
      (failure) => throw Exception(failure.message),
      (_) => null,
    );

    final confirmResult = await repo.confirmRequirementEvidence(
      _userId,
      _query.enrollmentId,
      _query.sectionId,
      evidenceId: ticket.evidenceId,
    );

    confirmResult.fold(
      (failure) => throw Exception(failure.message),
      (_) => null,
    );
  }

  /// Elimina una evidencia ya confirmada. [evidenceIdStr] es el `id` (String)
  /// que `EvidenceStagingManager` reporta para el `StagedFile`.
  Future<void> deleteComponentEvidence(String evidenceIdStr) async {
    final evidenceId = int.tryParse(evidenceIdStr);
    if (evidenceId == null) return;

    final result = await ref
        .read(certificationsRepositoryProvider)
        .deleteRequirementEvidence(_userId, _query.enrollmentId, evidenceId);

    result.fold(
      (failure) => throw Exception(failure.message),
      (_) => null,
    );
  }

  /// Limpia el mensaje de error mostrado.
  void clearError() => state = state.copyWith(errorMessage: null);
}

final certificationRequirementNotifierProvider = NotifierProvider.autoDispose
    .family<CertificationRequirementNotifier, CertificationRequirementState,
        CertificationRequirementQuery>(
  CertificationRequirementNotifier.new,
);

// ── Cierre (Task 12) ──────────────────────────────────────────────────────────

/// Estado del flujo de cierre (comprobante de junta + envío final).
class CertificationCloseoutState extends Equatable {
  final bool isUploading;
  final bool isSubmitting;
  final String? errorMessage;
  final bool closeoutEvidenceConfirmed;
  final bool submitSuccess;

  const CertificationCloseoutState({
    this.isUploading = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.closeoutEvidenceConfirmed = false,
    this.submitSuccess = false,
  });

  CertificationCloseoutState copyWith({
    bool? isUploading,
    bool? isSubmitting,
    String? errorMessage,
    bool? closeoutEvidenceConfirmed,
    bool? submitSuccess,
  }) {
    return CertificationCloseoutState(
      isUploading: isUploading ?? this.isUploading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
      closeoutEvidenceConfirmed:
          closeoutEvidenceConfirmed ?? this.closeoutEvidenceConfirmed,
      submitSuccess: submitSuccess ?? false,
    );
  }

  @override
  List<Object?> get props => [
        isUploading,
        isSubmitting,
        errorMessage,
        closeoutEvidenceConfirmed,
        submitSuccess,
      ];
}

/// Identifica el flujo de cierre de una inscripción.
///
/// `enrollmentId` conduce las llamadas al backend; `certificationId` se
/// conserva solo para invalidar el provider de progreso.
class CertificationCloseoutQuery extends Equatable {
  final int certificationId;
  final int enrollmentId;

  const CertificationCloseoutQuery({
    required this.certificationId,
    required this.enrollmentId,
  });

  @override
  List<Object?> get props => [certificationId, enrollmentId];
}

/// Notifier del cierre institucional — family por [CertificationCloseoutQuery].
class CertificationCloseoutNotifier extends AutoDisposeFamilyNotifier<
    CertificationCloseoutState, CertificationCloseoutQuery> {
  @override
  CertificationCloseoutState build(CertificationCloseoutQuery query) =>
      const CertificationCloseoutState();

  CertificationCloseoutQuery get _query => arg;

  String get _userId {
    final authState = ref.read(authNotifierProvider);
    return authState.value?.id ?? '';
  }

  /// Sube el comprobante de junta: presign → PUT directo a R2 → confirm.
  Future<bool> uploadCloseoutEvidence({
    required String filePath,
    required String fileName,
    required String mimeType,
    required int fileSize,
    void Function(double progress)? onProgress,
  }) async {
    state = state.copyWith(isUploading: true, errorMessage: null);
    final repo = ref.read(certificationsRepositoryProvider);

    final presignResult = await repo.presignCloseoutEvidence(
      _userId,
      _query.enrollmentId,
      fileName: fileName,
      mimeType: mimeType,
      fileSize: fileSize,
    );

    if (presignResult.isLeft()) {
      final message =
          presignResult.fold((failure) => failure.message, (_) => '');
      state = state.copyWith(isUploading: false, errorMessage: message);
      return false;
    }
    final ticket =
        presignResult.fold((_) => throw StateError('unreachable'), (t) => t);

    final uploadResult = await repo.uploadEvidenceFile(
      uploadUrl: ticket.uploadUrl,
      filePath: filePath,
      mimeType: mimeType,
      headers: ticket.requiredHeaders,
      onProgress: onProgress ?? (_) {},
    );

    if (uploadResult.isLeft()) {
      final message =
          uploadResult.fold((failure) => failure.message, (_) => '');
      state = state.copyWith(isUploading: false, errorMessage: message);
      return false;
    }

    final confirmResult = await repo.confirmCloseoutEvidence(
      _userId,
      _query.enrollmentId,
      closeoutEvidenceId: ticket.closeoutEvidenceId,
    );

    return confirmResult.fold(
      (failure) {
        state =
            state.copyWith(isUploading: false, errorMessage: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(
          isUploading: false,
          closeoutEvidenceConfirmed: true,
        );
        return true;
      },
    );
  }

  /// Envía la inscripción a revisión final.
  Future<bool> submitFinal() async {
    state = state.copyWith(
        isSubmitting: true, errorMessage: null, submitSuccess: false);

    final result = await ref
        .read(certificationsRepositoryProvider)
        .submitFinal(_userId, _query.enrollmentId);

    return result.fold(
      (failure) {
        state =
            state.copyWith(isSubmitting: false, errorMessage: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isSubmitting: false, submitSuccess: true);
        ref.invalidate(
          certificationProgressProvider(_query.certificationId),
        );
        return true;
      },
    );
  }

  void clearError() => state = state.copyWith(errorMessage: null);
}

final certificationCloseoutNotifierProvider = NotifierProvider.autoDispose
    .family<CertificationCloseoutNotifier, CertificationCloseoutState,
        CertificationCloseoutQuery>(
  CertificationCloseoutNotifier.new,
);
