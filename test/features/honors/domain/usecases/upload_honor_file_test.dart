import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor_category.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor_group.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor_requirement.dart';
import 'package:sacdia_app/features/honors/domain/entities/requirement_evidence.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor_requirement_progress.dart';
import 'package:sacdia_app/features/honors/domain/repositories/honors_repository.dart';
import 'package:sacdia_app/features/honors/domain/usecases/register_user_honor.dart';
import 'package:sacdia_app/features/honors/domain/usecases/upload_honor_file.dart';

class _FakeHonorsRepository implements HonorsRepository {
  String? capturedUserId;
  int? capturedHonorId;
  String? capturedPath;
  String? capturedFileName;
  Either<Failure, void> result = const Right(null);

  @override
  Future<Either<Failure, void>> uploadHonorFile(
      {required String userId,
      required int honorId,
      required File file,
      required String fileName}) async {
    capturedUserId = userId;
    capturedHonorId = honorId;
    capturedPath = file.path;
    capturedFileName = fileName;
    return result;
  }

  @override
  Future<Either<Failure, RequirementEvidence>> addRequirementEvidenceLink(
          String userId, int honorId, int requirementId, String url) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, List<UserHonorRequirementProgress>>>
      bulkUpdateRequirementProgress(
              String userId, int honorId, List<Map<String, dynamic>> updates) =>
          throw UnimplementedError();
  @override
  Future<Either<Failure, void>> deleteRequirementEvidence(
          String userId, int honorId, int requirementId, int evidenceId) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, void>> deleteUserHonor(String userId, int honorId) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, UserHonor>> enrollUserInHonor(
          String userId, int honorId) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, Honor>> getHonorById(int honorId,
          {CancelToken? cancelToken}) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, List<HonorCategory>>> getHonorCategories(
          {CancelToken? cancelToken}) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, List<HonorRequirement>>> getHonorRequirements(
          int honorId,
          {CancelToken? cancelToken}) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, List<Honor>>> getHonors(
          {int? categoryId,
          int? clubTypeId,
          int? skillLevel,
          CancelToken? cancelToken}) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, List<HonorGroup>>> getHonorsGroupedByCategory(
          {CancelToken? cancelToken}) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, List<RequirementEvidence>>> getRequirementEvidences(
          String userId, int honorId, int requirementId,
          {CancelToken? cancelToken}) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, List<UserHonorRequirementProgress>>>
      getUserHonorProgress(String userId, int honorId,
              {CancelToken? cancelToken}) =>
          throw UnimplementedError();
  @override
  Future<Either<Failure, Map<String, dynamic>>> getUserHonorStats(String userId,
          {CancelToken? cancelToken}) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, List<UserHonor>>> getUserHonors(String userId,
          {CancelToken? cancelToken}) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, UserHonor>> registerUserHonor(
          RegisterUserHonorParams params) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, UserHonorRequirementProgress>>
      updateRequirementProgress(
              {required String userId,
              required int honorId,
              required int requirementId,
              required bool completed,
              String? notes}) =>
          throw UnimplementedError();
  @override
  Future<Either<Failure, UserHonor>> updateUserHonor(
          String userId, int honorId, Map<String, dynamic> data) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, RequirementEvidence>> uploadRequirementEvidence(
          String userId, int honorId, int requirementId, File file,
          {required String mimeType}) =>
      throw UnimplementedError();
}

void main() {
  test('delegates honor file upload to repository', () async {
    final repo = _FakeHonorsRepository();
    final useCase = UploadHonorFile(repo);
    final file = File('${Directory.systemTemp.path}/honor.pdf');

    final result = await useCase(
      UploadHonorFileParams(
        userId: 'user-1',
        honorId: 7,
        file: file,
        fileName: 'honor.pdf',
      ),
    );

    expect(result, const Right(null));
    expect(repo.capturedUserId, 'user-1');
    expect(repo.capturedHonorId, 7);
    expect(repo.capturedPath, file.path);
    expect(repo.capturedFileName, 'honor.pdf');
  });
}
