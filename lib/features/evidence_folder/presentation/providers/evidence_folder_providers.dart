import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
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

final submitFolderUseCaseProvider = Provider<SubmitFolder>((ref) {
  return SubmitFolder(ref.read(evidenceFolderRepositoryProvider));
});

final submitSectionUseCaseProvider = Provider<SubmitSection>((ref) {
  return SubmitSection(ref.read(evidenceFolderRepositoryProvider));
});

final uploadEvidenceFileUseCaseProvider = Provider<UploadEvidenceFile>((ref) {
  return UploadEvidenceFile(ref.read(evidenceFolderRepositoryProvider));
});

final deleteEvidenceFileUseCaseProvider = Provider<DeleteEvidenceFile>((ref) {
  return DeleteEvidenceFile(ref.read(evidenceFolderRepositoryProvider));
});

// ── Data providers ────────────────────────────────────────────────────────────

/// Provider que carga la carpeta de evidencias para una sección de club.
///
/// autoDispose para liberar memoria al salir de la pantalla.
///
/// Retorna `null` cuando la carpeta aún no fue creada (estado de negocio
/// válido — backend responde `200 + data: null`). La vista discrimina en
/// el branch `data:` en lugar de `error:`.
///
/// Fallback defensivo: si el backend todavía devuelve 404 (durante la
/// transición), el repositorio lo mapea a [NotFoundFailure] y el provider
/// lo re-lanza como [NotFoundException] para que la view lo trate igual
/// que `null` en el branch `error:`.
final evidenceFolderProvider = FutureProvider.autoDispose
    .family<EvidenceFolder?, String>((ref, clubSectionId) async {
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final useCase = ref.read(getEvidenceFolderUseCaseProvider);
  final result = await useCase(
    GetEvidenceFolderParams(clubSectionId: clubSectionId),
    cancelToken: cancelToken,
  );

  return result.fold(
    (failure) {
      // Fallback defensivo: backend viejo que todavía devuelve 404.
      if (failure is NotFoundFailure) {
        throw NotFoundException(message: failure.message, code: failure.code);
      }
      throw Exception(failure.message);
    },
    // folder puede ser null (carpeta no existe) — es un Right válido.
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
///
/// El [arg] es el [clubSectionId] (integer como String). El [folderId] UUID se
/// obtiene desde la carpeta ya cargada en [evidenceFolderProvider].
class EvidenceSectionNotifier
    extends AutoDisposeFamilyNotifier<SectionOperationState, String> {
  @override
  SectionOperationState build(String clubSectionId) =>
      const SectionOperationState();

  String get _clubSectionId => arg;

  /// Resuelve el folderId UUID desde la carpeta cargada en el provider.
  ///
  /// Lanza [StateError] si la carpeta no está disponible todavía o si es null
  /// (carpeta no creada — no se pueden realizar mutaciones sin folderId).
  String _resolveFolderId() {
    final folderAsync = ref.read(evidenceFolderProvider(_clubSectionId));
    return folderAsync.maybeWhen(
      data: (folder) {
        if (folder == null) {
          throw StateError(
            'La carpeta no existe aún. No se pueden realizar operaciones '
            'sin una carpeta creada.',
          );
        }
        return folder.folderId;
      },
      orElse: () => throw StateError(
        'La carpeta no está cargada. Asegúrese de que evidenceFolderProvider '
        'haya completado antes de invocar operaciones de mutación.',
      ),
    );
  }

  /// Envía la carpeta completa a validación.
  ///
  /// AnnualFolders opera sobre carpeta completa — no por sección individual.
  Future<bool> submitFolder() async {
    state = state.copyWith(isLoading: true, errorMessage: null, success: false);

    final String folderId;
    try {
      folderId = _resolveFolderId();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }

    final result = await ref.read(submitFolderUseCaseProvider)(
      SubmitFolderParams(folderId: folderId),
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
        ref.invalidate(evidenceFolderProvider(_clubSectionId));
        return true;
      },
    );
  }

  /// Envía una sección individual a validación.
  ///
  /// [sectionId] es el UUID de la sección dentro de la carpeta anual.
  Future<bool> submitSection(String sectionId) async {
    state = state.copyWith(isLoading: true, errorMessage: null, success: false);

    final String folderId;
    try {
      folderId = _resolveFolderId();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }

    final result = await ref.read(submitSectionUseCaseProvider)(
      SubmitSectionParams(folderId: folderId, sectionId: sectionId),
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
        ref.invalidate(evidenceFolderProvider(_clubSectionId));
        return true;
      },
    );
  }

  /// Sube un archivo a la sección indicada.
  ///
  /// [sectionId] es el UUID de la sección dentro de la carpeta anual.
  /// [pickedFile] proviene de [ImagePicker] o [FilePicker].
  /// [onProgress] callback opcional que recibe la fracción de progreso (0.0 – 1.0).
  /// [skipInvalidation] si es `true`, omite el invalidate de [evidenceFolderProvider]
  /// tras la subida (útil en subidas por lote para evitar refrescos por archivo).
  Future<bool> uploadFile({
    required String sectionId,
    required XFile pickedFile,
    required String mimeType,
    String? notes,
    void Function(double)? onProgress,
    bool skipInvalidation = false,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null, success: false);

    final String folderId;
    try {
      folderId = _resolveFolderId();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }

    final result = await ref.read(uploadEvidenceFileUseCaseProvider)(
      UploadEvidenceFileParams(
        folderId: folderId,
        sectionId: sectionId,
        filePath: pickedFile.path,
        fileName: pickedFile.name,
        mimeType: mimeType,
        notes: notes,
        onProgress: onProgress,
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
        if (!skipInvalidation) {
          ref.invalidate(evidenceFolderProvider(_clubSectionId));
        }
        return true;
      },
    );
  }

  /// Elimina un archivo de evidencia.
  ///
  /// [fileId] es el evidence_id UUID del archivo a eliminar.
  Future<bool> deleteFile({required String fileId}) async {
    state = state.copyWith(isLoading: true, errorMessage: null, success: false);

    final result = await ref.read(deleteEvidenceFileUseCaseProvider)(
      DeleteEvidenceFileParams(evidenceId: fileId),
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
        ref.invalidate(evidenceFolderProvider(_clubSectionId));
        return true;
      },
    );
  }

  /// Limpia el estado de error / éxito.
  void reset() => state = const SectionOperationState();
}

/// Provider para el notifier de operaciones de sección.
///
/// Es un family por [clubSectionId] para que cada sección de club
/// tenga su propio estado de operación.
final evidenceSectionNotifierProvider = NotifierProvider.autoDispose
    .family<EvidenceSectionNotifier, SectionOperationState, String>(
  EvidenceSectionNotifier.new,
);
