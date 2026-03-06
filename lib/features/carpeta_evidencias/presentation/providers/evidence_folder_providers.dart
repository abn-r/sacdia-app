import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../providers/dio_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/evidence_folder_remote_data_source.dart';
import '../../data/repositories/evidence_folder_repository_impl.dart';
import '../../domain/entities/evidence_folder.dart';
import '../../domain/repositories/evidence_folder_repository.dart';
import '../../domain/usecases/delete_evidence_file.dart';
import '../../domain/usecases/get_evidence_folder.dart';
import '../../domain/usecases/submit_section.dart';
import '../../domain/usecases/upload_evidence_file.dart';

// ── Infrastructure providers ──────────────────────────────────────────────────

/// Provider para el datasource remoto de carpeta de evidencias.
final evidenceFolderRemoteDataSourceProvider =
    Provider<EvidenceFolderRemoteDataSource>((ref) {
  return EvidenceFolderRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

/// Provider para el repositorio de carpeta de evidencias.
final evidenceFolderRepositoryProvider =
    Provider<EvidenceFolderRepository>((ref) {
  return EvidenceFolderRepositoryImpl(
    remoteDataSource: ref.read(evidenceFolderRemoteDataSourceProvider),
    networkInfo: ref.read(networkInfoProvider),
  );
});

// ── Use case providers ────────────────────────────────────────────────────────

final getEvidenceFolderUseCaseProvider = Provider<GetEvidenceFolder>((ref) {
  return GetEvidenceFolder(ref.read(evidenceFolderRepositoryProvider));
});

final submitSectionUseCaseProvider = Provider<SubmitSection>((ref) {
  return SubmitSection(ref.read(evidenceFolderRepositoryProvider));
});

final uploadEvidenceFileUseCaseProvider =
    Provider<UploadEvidenceFile>((ref) {
  return UploadEvidenceFile(ref.read(evidenceFolderRepositoryProvider));
});

final deleteEvidenceFileUseCaseProvider =
    Provider<DeleteEvidenceFile>((ref) {
  return DeleteEvidenceFile(ref.read(evidenceFolderRepositoryProvider));
});

// ── Data providers ────────────────────────────────────────────────────────────

/// Provider que carga la carpeta de evidencias para una instancia de club.
///
/// autoDispose para liberar memoria al salir de la pantalla.
final evidenceFolderProvider = FutureProvider.autoDispose
    .family<EvidenceFolder, String>((ref, clubInstanceId) async {
  final useCase = ref.read(getEvidenceFolderUseCaseProvider);
  final result =
      await useCase(GetEvidenceFolderParams(clubInstanceId: clubInstanceId));

  return result.fold(
    (failure) => throw Exception(failure.message),
    (folder) => folder,
  );
});

// ── Section operations state ──────────────────────────────────────────────────

/// Estado para operaciones de sección (submit, upload, delete).
class SectionOperationState {
  final bool isLoading;
  final String? errorMessage;
  final bool success;

  const SectionOperationState({
    this.isLoading = false,
    this.errorMessage,
    this.success = false,
  });

  SectionOperationState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? success,
  }) {
    return SectionOperationState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      success: success ?? this.success,
    );
  }
}

/// Notifier para gestionar el estado de la sección activa (detalle).
///
/// Maneja operaciones de subida de archivos, eliminación y envío a validación.
/// Al completar con éxito cualquier mutación, invalida [evidenceFolderProvider]
/// para refrescar datos frescos del backend.
class EvidenceSectionNotifier
    extends StateNotifier<SectionOperationState> {
  final SubmitSection _submitSection;
  final UploadEvidenceFile _uploadFile;
  final DeleteEvidenceFile _deleteFile;
  final Ref _ref;
  final String _clubInstanceId;

  EvidenceSectionNotifier({
    required SubmitSection submitSection,
    required UploadEvidenceFile uploadFile,
    required DeleteEvidenceFile deleteFile,
    required Ref ref,
    required String clubInstanceId,
  })  : _submitSection = submitSection,
        _uploadFile = uploadFile,
        _deleteFile = deleteFile,
        _ref = ref,
        _clubInstanceId = clubInstanceId,
        super(const SectionOperationState());

  /// Envía una sección a validación (pendiente → enviado).
  Future<bool> submit(String sectionId) async {
    state = state.copyWith(isLoading: true, errorMessage: null, success: false);

    final result = await _submitSection(
      SubmitSectionParams(
        clubInstanceId: _clubInstanceId,
        sectionId: sectionId,
      ),
    );

    return result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: failure.message,
        );
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false, success: true);
        _ref.invalidate(evidenceFolderProvider(_clubInstanceId));
        return true;
      },
    );
  }

  /// Sube un archivo a la sección indicada.
  ///
  /// [pickedFile] proviene de [ImagePicker] o [FilePicker].
  Future<bool> uploadFile({
    required String sectionId,
    required XFile pickedFile,
    required String mimeType,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null, success: false);

    final result = await _uploadFile(
      UploadEvidenceFileParams(
        clubInstanceId: _clubInstanceId,
        sectionId: sectionId,
        filePath: pickedFile.path,
        fileName: pickedFile.name,
        mimeType: mimeType,
      ),
    );

    return result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: failure.message,
        );
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false, success: true);
        _ref.invalidate(evidenceFolderProvider(_clubInstanceId));
        return true;
      },
    );
  }

  /// Elimina un archivo de evidencia.
  Future<bool> deleteFile({
    required String sectionId,
    required String fileId,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null, success: false);

    final result = await _deleteFile(
      DeleteEvidenceFileParams(
        clubInstanceId: _clubInstanceId,
        sectionId: sectionId,
        fileId: fileId,
      ),
    );

    return result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: failure.message,
        );
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false, success: true);
        _ref.invalidate(evidenceFolderProvider(_clubInstanceId));
        return true;
      },
    );
  }

  /// Limpia el estado de error / éxito.
  void reset() => state = const SectionOperationState();
}

/// Provider para el notifier de operaciones de sección.
///
/// Es un family por [clubInstanceId] para que cada instancia de club
/// tenga su propio estado de operación.
final evidenceSectionNotifierProvider = StateNotifierProvider.autoDispose
    .family<EvidenceSectionNotifier, SectionOperationState, String>(
  (ref, clubInstanceId) => EvidenceSectionNotifier(
    submitSection: ref.read(submitSectionUseCaseProvider),
    uploadFile: ref.read(uploadEvidenceFileUseCaseProvider),
    deleteFile: ref.read(deleteEvidenceFileUseCaseProvider),
    ref: ref,
    clubInstanceId: clubInstanceId,
  ),
);
