import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/evidence_folder/domain/entities/evidence_file.dart';
import 'package:sacdia_app/features/evidence_folder/domain/entities/evidence_folder.dart';
import 'package:sacdia_app/features/evidence_folder/domain/repositories/evidence_folder_repository.dart';
import 'package:sacdia_app/features/evidence_folder/presentation/providers/evidence_folder_providers.dart';

class _CountingEvidenceFolderRepository implements EvidenceFolderRepository {
  int getFolderCalls = 0;

  @override
  Future<Either<Failure, EvidenceFolder?>> getEvidenceFolder(
    String clubSectionId, {
    RequestCancelToken? cancelToken,
  }) async {
    getFolderCalls++;
    return const Right(null);
  }

  @override
  Future<Either<Failure, EvidenceFolder>> createEvidenceFolder(
    String clubSectionId,
  ) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, void>> submitFolder(String folderId) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, void>> submitSection({
    required String folderId,
    required String sectionId,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, EvidenceFile>> uploadFile({
    required String folderId,
    required String sectionId,
    required String filePath,
    required String fileName,
    required String mimeType,
    String? notes,
    void Function(double)? onProgress,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, void>> deleteFile({required String evidenceId}) =>
      throw UnimplementedError();
}

void main() {
  test('keeps a loaded folder cached after the view stops listening', () async {
    final repository = _CountingEvidenceFolderRepository();
    final container = ProviderContainer(
      overrides: [
        evidenceFolderRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(
      evidenceFolderProvider('club-section-1'),
      (_, __) {},
    );
    await container.read(evidenceFolderProvider('club-section-1').future);
    expect(repository.getFolderCalls, 1);

    subscription.close();
    await container.pump();

    await container.read(evidenceFolderProvider('club-section-1').future);

    expect(repository.getFolderCalls, 1);
  });
}
