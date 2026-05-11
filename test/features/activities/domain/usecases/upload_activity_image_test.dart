import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/activities/domain/entities/activity.dart';
import 'package:sacdia_app/features/activities/domain/entities/attendance.dart';
import 'package:sacdia_app/features/activities/domain/repositories/activities_repository.dart';
import 'package:sacdia_app/features/activities/domain/usecases/upload_activity_image.dart';
import 'package:sacdia_app/features/activities/data/models/create_activity_request.dart';

class _FakeActivitiesRepository implements ActivitiesRepository {
  int? capturedActivityId;
  String? capturedPath;
  Either<Failure, String> result = const Right('https://cdn.example/img.jpg');

  @override
  Future<Either<Failure, String>> uploadActivityImage(
    int activityId,
    File imageFile,
  ) async {
    capturedActivityId = activityId;
    capturedPath = imageFile.path;
    return result;
  }

  @override
  Future<Either<Failure, Activity>> createActivity(
          {required int clubId, required CreateActivityRequest request}) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, void>> deleteActivity(int activityId) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, List<Attendance>>> getActivityAttendance(
          int activityId,
          {CancelToken? cancelToken}) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, Activity>> getActivityById(int activityId,
          {CancelToken? cancelToken}) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, List<Activity>>> getClubActivities(int clubId,
          {int? clubTypeId, CancelToken? cancelToken}) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, int>> registerAttendance(
          int activityId, List<String> userIds) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, Activity>> updateActivity(
          {required int activityId,
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
          List<int>? clubSectionIds}) =>
      throw UnimplementedError();
}

void main() {
  test('delegates activity image upload to repository', () async {
    final repo = _FakeActivitiesRepository();
    final useCase = UploadActivityImage(repo);
    final file = File('${Directory.systemTemp.path}/activity.jpg');

    final result = await useCase(
      UploadActivityImageParams(activityId: 42, imageFile: file),
    );

    expect(result, const Right('https://cdn.example/img.jpg'));
    expect(repo.capturedActivityId, 42);
    expect(repo.capturedPath, file.path);
  });
}
