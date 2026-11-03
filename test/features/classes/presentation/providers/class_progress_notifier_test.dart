import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/classes/domain/entities/class_progress.dart';
import 'package:sacdia_app/features/classes/domain/entities/track_progress.dart';
import 'package:sacdia_app/features/classes/domain/repositories/classes_repository.dart';
import 'package:sacdia_app/features/classes/domain/usecases/update_class_progress.dart';
import 'package:sacdia_app/features/classes/presentation/providers/classes_providers.dart';

import '../../../../support/riverpod_test_support.dart';

const _progress = ClassProgress(
  classId: 3,
  totalSections: 10,
  completedSections: 4,
  percentage: 40,
  basicProgress: TrackProgress(percentage: 40),
  advancedProgress: TrackProgress(percentage: 0),
  extraProgress: TrackProgress(percentage: 0),
);

/// Update that takes a moment, like a real network call.
class _SlowUpdate implements UpdateClassProgress {
  _SlowUpdate(this.result);

  final Either<Failure, ClassProgress> result;

  @override
  ClassesRepository get repository => throw UnimplementedError();

  @override
  Future<Either<Failure, ClassProgress>> call(
      UpdateClassProgressParams params) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return result;
  }
}

void main() {
  // The section views only `ref.read` this notifier, so nothing listens to it.
  // An autoDispose provider is then disposed while the update is in flight,
  // and writing `state` after the await threw.
  test('updateProgress completes when nothing listens to the notifier',
      () async {
    final container = createTestContainer(overrides: [
      updateClassProgressProvider
          .overrideWithValue(_SlowUpdate(const Right(_progress))),
    ]);

    await container
        .read(classProgressNotifierProvider.notifier)
        .updateProgress('u1', 3, {'section': 1});

    expect(container.read(classProgressNotifierProvider).value, _progress);
  });

  test('a failed update leaves the failure message in the state', () async {
    final container = createTestContainer(overrides: [
      updateClassProgressProvider.overrideWithValue(
          _SlowUpdate(const Left(ServerFailure(message: 'boom')))),
    ]);

    await container
        .read(classProgressNotifierProvider.notifier)
        .updateProgress('u1', 3, {'section': 1});

    expect(container.read(classProgressNotifierProvider).error, 'boom');
  });
}
