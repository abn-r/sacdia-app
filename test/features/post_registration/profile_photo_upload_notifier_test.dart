import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/post_registration/domain/repositories/post_registration_repository.dart';
import 'package:sacdia_app/features/post_registration/domain/usecases/upload_profile_picture.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/post_registration_providers.dart';

import '../../support/riverpod_test_support.dart';

/// Upload that takes a moment, like a real network call.
class _SlowUpload implements UploadProfilePicture {
  _SlowUpload(this.result);

  final Either<Failure, String> result;

  @override
  PostRegistrationRepository get repository => throw UnimplementedError();

  @override
  Future<Either<Failure, String>> call(
      UploadProfilePictureParams params) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return result;
  }
}

void main() {
  // The photo views only `ref.read` this notifier, so nothing listens to it.
  // An autoDispose provider is then disposed while the upload is in flight,
  // and touching `ref` after the await threw: the view showed "Error al
  // recortar la imagen" and the uploading spinner never stopped.
  test('upload completes when nothing listens to the notifier', () async {
    final container = createTestContainer(overrides: [
      uploadProfilePictureProvider
          .overrideWithValue(_SlowUpload(const Right('https://cdn/p.jpg'))),
    ]);
    addTearDown(container.dispose);
    final uploading = container.listen(isUploadingPhotoProvider, (_, __) {});

    final ok = await container
        .read(profilePhotoUploadNotifierProvider.notifier)
        .upload(userId: 'u1', filePath: '/tmp/p.jpg');

    expect(ok, isTrue);
    expect(uploading.read(), isFalse);
  });

  test('a failed upload reports false and clears the uploading flag', () async {
    final container = createTestContainer(overrides: [
      uploadProfilePictureProvider.overrideWithValue(
          _SlowUpload(const Left(ServerFailure(message: 'boom')))),
    ]);
    addTearDown(container.dispose);
    final uploading = container.listen(isUploadingPhotoProvider, (_, __) {});

    final ok = await container
        .read(profilePhotoUploadNotifierProvider.notifier)
        .upload(userId: 'u1', filePath: '/tmp/p.jpg');

    expect(ok, isFalse);
    expect(uploading.read(), isFalse);
    // The photo step reads the message right after the await.
    expect(container.read(profilePhotoUploadNotifierProvider).error, 'boom');
  });
}
