import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/evidence_folder/domain/entities/evidence_file.dart';
import 'package:sacdia_app/features/evidence_folder/domain/entities/evidence_folder.dart';
import 'package:sacdia_app/features/evidence_folder/domain/repositories/evidence_folder_repository.dart';
import 'package:sacdia_app/features/evidence_folder/presentation/providers/evidence_folder_providers.dart';

import '../../support/riverpod_test_support.dart';

const _folder = EvidenceFolder(
  folderId: 'folder-1',
  id: '1',
  name: 'Carpeta',
  isOpen: true,
  totalPoints: 0,
  totalPercentage: 0,
  sections: [],
);

/// Every mutation takes a moment, like a real network call.
class _SlowRepository implements EvidenceFolderRepository {
  _SlowRepository({this.failure});

  final Failure? failure;

  Future<Either<Failure, T>> _result<T>(T value) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final failure = this.failure;
    return failure == null ? Right(value) : Left(failure);
  }

  @override
  Future<Either<Failure, void>> submitFolder(String folderId) =>
      _result<void>(null);

  @override
  Future<Either<Failure, void>> submitSection({
    required String folderId,
    required String sectionId,
  }) =>
      _result<void>(null);

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
      _result(EvidenceFile(
        id: 'f1',
        url: 'https://cdn/f.jpg',
        fileName: fileName,
        type: EvidenceFileType.image,
        uploadedByName: 'Ana',
        uploadedAt: DateTime(2026, 11, 3),
      ));

  @override
  Future<Either<Failure, void>> deleteFile({required String evidenceId}) =>
      _result<void>(null);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Future<
    ({
      dynamic container,
      EvidenceSectionNotifier Function() notifier,
      SectionOperationState Function() state,
    })> _setup({Failure? failure}) async {
  final container = createTestContainer(overrides: [
    evidenceFolderRepositoryProvider
        .overrideWithValue(_SlowRepository(failure: failure)),
    evidenceFolderProvider('1').overrideWith((ref) async {
      ref.keepAlive();
      return _folder;
    }),
  ]);
  await container.read(evidenceFolderProvider('1').future);
  return (
    container: container,
    notifier: () =>
        container.read(evidenceSectionNotifierProvider('1').notifier),
    state: () => container.read(evidenceSectionNotifierProvider('1')),
  );
}

void main() {
  // The evidence views only `ref.read` this notifier, so nothing listens to
  // it. An autoDispose provider is then disposed while the request is in
  // flight, and writing `state` after the await threw.
  test('submitSection completes when nothing listens', () async {
    final t = await _setup();

    final ok = await t.notifier().submitSection('s1');

    expect(ok, isTrue);
    expect(t.state().success, isTrue);
    expect(t.state().isLoading, isFalse);
  });

  test('submitFolder completes when nothing listens', () async {
    final t = await _setup();

    final ok = await t.notifier().submitFolder();

    expect(ok, isTrue);
    expect(t.state().success, isTrue);
  });

  test('uploadFile completes when nothing listens', () async {
    final t = await _setup();

    final ok = await t.notifier().uploadFile(
          sectionId: 's1',
          pickedFile: XFile('/tmp/a.jpg', name: 'a.jpg'),
          mimeType: 'image/jpeg',
        );

    expect(ok, isTrue);
    expect(t.state().success, isTrue);
  });

  test('deleteFile completes when nothing listens', () async {
    final t = await _setup();

    final ok = await t.notifier().deleteFile(fileId: 'f1');

    expect(ok, isTrue);
    expect(t.state().success, isTrue);
  });

  test('a failed submit reports false and keeps the message', () async {
    final t = await _setup(failure: const ServerFailure(message: 'boom'));

    final ok = await t.notifier().submitSection('s1');

    expect(ok, isFalse);
    expect(t.state().errorMessage, 'boom');
    expect(t.state().isLoading, isFalse);
  });
}
