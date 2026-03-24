import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/dio_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/annual_folders_remote_data_source.dart';
import '../../data/repositories/annual_folders_repository_impl.dart';
import '../../domain/entities/annual_folder.dart';
import '../../domain/repositories/annual_folders_repository.dart';

// ── Infrastructure providers ──────────────────────────────────────────────────

final annualFoldersRemoteDataSourceProvider =
    Provider<AnnualFoldersRemoteDataSource>((ref) {
  return AnnualFoldersRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

final annualFoldersRepositoryProvider =
    Provider<AnnualFoldersRepository>((ref) {
  return AnnualFoldersRepositoryImpl(
    remoteDataSource: ref.read(annualFoldersRemoteDataSourceProvider),
    networkInfo: ref.read(networkInfoProvider),
  );
});

// ── Data providers ────────────────────────────────────────────────────────────

/// Provider de la carpeta anual por enrollment.
final annualFolderByEnrollmentProvider =
    FutureProvider.autoDispose.family<AnnualFolder, int>(
        (ref, enrollmentId) async {
  final repo = ref.read(annualFoldersRepositoryProvider);
  final result = await repo.getFolderByEnrollment(enrollmentId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (folder) => folder,
  );
});

// ── Upload Evidence notifier ──────────────────────────────────────────────────

class UploadEvidenceState {
  final bool isLoading;
  final String? errorMessage;
  final bool success;

  const UploadEvidenceState({
    this.isLoading = false,
    this.errorMessage,
    this.success = false,
  });

  UploadEvidenceState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? success,
  }) {
    return UploadEvidenceState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      success: success ?? this.success,
    );
  }
}

class UploadEvidenceNotifier
    extends AutoDisposeFamilyNotifier<UploadEvidenceState, int> {
  @override
  UploadEvidenceState build(int folderId) => const UploadEvidenceState();

  int get _folderId => arg;

  Future<bool> upload({
    required int sectionId,
    required String fileUrl,
    required String fileName,
    String? notes,
    required int enrollmentId,
  }) async {
    state = state.copyWith(
        isLoading: true, errorMessage: null, success: false);

    final result =
        await ref.read(annualFoldersRepositoryProvider).uploadEvidence(
              _folderId,
              sectionId: sectionId,
              fileUrl: fileUrl,
              fileName: fileName,
              notes: notes,
            );

    return result.fold(
      (failure) {
        state = state.copyWith(
            isLoading: false, errorMessage: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false, success: true);
        ref.invalidate(annualFolderByEnrollmentProvider(enrollmentId));
        return true;
      },
    );
  }

  void reset() => state = const UploadEvidenceState();
}

final uploadEvidenceNotifierProvider = NotifierProvider.autoDispose
    .family<UploadEvidenceNotifier, UploadEvidenceState, int>(
  UploadEvidenceNotifier.new,
);

// ── Delete Evidence notifier ──────────────────────────────────────────────────

class DeleteEvidenceState {
  final bool isLoading;
  final String? errorMessage;
  final bool success;

  const DeleteEvidenceState({
    this.isLoading = false,
    this.errorMessage,
    this.success = false,
  });

  DeleteEvidenceState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? success,
  }) {
    return DeleteEvidenceState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      success: success ?? this.success,
    );
  }
}

class DeleteEvidenceNotifier
    extends AutoDisposeNotifier<DeleteEvidenceState> {
  @override
  DeleteEvidenceState build() => const DeleteEvidenceState();

  Future<bool> delete(int evidenceId, {required int enrollmentId}) async {
    state = state.copyWith(
        isLoading: true, errorMessage: null, success: false);

    final result = await ref
        .read(annualFoldersRepositoryProvider)
        .deleteEvidence(evidenceId);

    return result.fold(
      (failure) {
        state = state.copyWith(
            isLoading: false, errorMessage: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false, success: true);
        ref.invalidate(annualFolderByEnrollmentProvider(enrollmentId));
        return true;
      },
    );
  }

  void reset() => state = const DeleteEvidenceState();
}

final deleteEvidenceProvider =
    NotifierProvider.autoDispose<DeleteEvidenceNotifier, DeleteEvidenceState>(
  DeleteEvidenceNotifier.new,
);

// ── Submit Folder notifier ────────────────────────────────────────────────────

class SubmitFolderState {
  final bool isLoading;
  final String? errorMessage;
  final bool success;

  const SubmitFolderState({
    this.isLoading = false,
    this.errorMessage,
    this.success = false,
  });

  SubmitFolderState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? success,
  }) {
    return SubmitFolderState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      success: success ?? this.success,
    );
  }
}

class SubmitFolderNotifier
    extends AutoDisposeFamilyNotifier<SubmitFolderState, int> {
  @override
  SubmitFolderState build(int folderId) => const SubmitFolderState();

  int get _folderId => arg;

  Future<bool> submit({required int enrollmentId}) async {
    state = state.copyWith(
        isLoading: true, errorMessage: null, success: false);

    final result = await ref
        .read(annualFoldersRepositoryProvider)
        .submitFolder(_folderId);

    return result.fold(
      (failure) {
        state = state.copyWith(
            isLoading: false, errorMessage: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false, success: true);
        ref.invalidate(annualFolderByEnrollmentProvider(enrollmentId));
        return true;
      },
    );
  }

  void reset() => state = const SubmitFolderState();
}

final submitFolderNotifierProvider = NotifierProvider.autoDispose
    .family<SubmitFolderNotifier, SubmitFolderState, int>(
  SubmitFolderNotifier.new,
);
