import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/activities/domain/entities/activity.dart';
import 'package:sacdia_app/features/activities/domain/repositories/activities_repository.dart';
import 'package:sacdia_app/features/activities/domain/usecases/upload_activity_image.dart';
import 'package:sacdia_app/features/activities/presentation/providers/activities_providers.dart';

import '../../../../support/riverpod_test_support.dart';

const _activity = Activity(
  id: 9,
  name: 'Campamento',
  activityPlace: 'Lago',
  activityType: 1,
  platform: 0,
  active: true,
  clubSectionId: 2,
  clubTypeId: 1,
);

const _delay = Duration(milliseconds: 20);

/// Update that takes a moment, like a real network call.
class _SlowRepository implements ActivitiesRepository {
  _SlowRepository({this.failure});

  final Failure? failure;

  @override
  Future<Either<Failure, Activity>> updateActivity({
    required int activityId,
    String? name,
    String? description,
    double? lat,
    double? long,
    String? activityTime,
    String? activityDate,
    String? activityEndDate,
    String? activityPlace,
    int? platform,
    int? activityTypeId,
    String? linkMeet,
    bool? active,
    Set<String> clearFields = const {},
    List<int>? clubSectionIds,
    String? image,
    String? audience,
    List<int>? classes,
  }) async {
    await Future<void>.delayed(_delay);
    final failure = this.failure;
    return failure == null ? const Right(_activity) : Left(failure);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _SlowImageUpload implements UploadActivityImage {
  _SlowImageUpload(this.result);

  final Either<Failure, String> result;

  @override
  ActivitiesRepository get repository => throw UnimplementedError();

  @override
  Future<Either<Failure, String>> call(UploadActivityImageParams params) async {
    await Future<void>.delayed(_delay);
    return result;
  }
}

void main() {
  // The activity views only `ref.read` these notifiers, so nothing listens to
  // them. An autoDispose provider is then disposed while the request is in
  // flight, and touching `ref`/`state` after the await threw.
  group('UpdateActivityNotifier', () {
    test('update completes when nothing listens', () async {
      final container = createTestContainer(overrides: [
        activitiesRepositoryProvider.overrideWithValue(_SlowRepository()),
      ]);

      final ok = await container
          .read(updateActivityNotifierProvider.notifier)
          .update(activityId: 9, name: 'Campamento');

      expect(ok, isTrue);
      final state = container.read(updateActivityNotifierProvider);
      expect(state.isLoading, isFalse);
      expect(state.updatedActivity, _activity);
    });

    test('a failed update reports false and keeps the message', () async {
      final container = createTestContainer(overrides: [
        activitiesRepositoryProvider.overrideWithValue(
            _SlowRepository(failure: const ServerFailure(message: 'boom'))),
      ]);

      final ok = await container
          .read(updateActivityNotifierProvider.notifier)
          .update(activityId: 9);

      expect(ok, isFalse);
      expect(
          container.read(updateActivityNotifierProvider).errorMessage, 'boom');
    });
  });

  group('ActivityImageUploadNotifier', () {
    test('upload completes when nothing listens', () async {
      final container = createTestContainer(overrides: [
        uploadActivityImageProvider.overrideWithValue(
            _SlowImageUpload(const Right('https://cdn/i.jpg'))),
      ]);

      final ok = await container
          .read(activityImageUploadNotifierProvider.notifier)
          .upload(activityId: 9, imageFile: File('/tmp/i.jpg'));

      expect(ok, isTrue);
      expect(container.read(activityImageUploadNotifierProvider).value,
          'https://cdn/i.jpg');
    });

    test('a failed upload reports false and keeps the message', () async {
      final container = createTestContainer(overrides: [
        uploadActivityImageProvider.overrideWithValue(
            _SlowImageUpload(const Left(ServerFailure(message: 'boom')))),
      ]);

      final ok = await container
          .read(activityImageUploadNotifierProvider.notifier)
          .upload(activityId: 9, imageFile: File('/tmp/i.jpg'));

      expect(ok, isFalse);
      expect(container.read(activityImageUploadNotifierProvider).error, 'boom');
    });
  });
}
