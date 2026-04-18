import 'dart:io';

import 'package:dartz/dartz.dart';
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
import 'package:sacdia_app/features/honors/domain/usecases/upload_requirement_evidence.dart';
import 'package:dio/dio.dart';

// ── Stub repository ───────────────────────────────────────────────────────────

class _StubHonorsRepository implements HonorsRepository {
  String? capturedMimeType;
  Either<Failure, RequirementEvidence> uploadResult = const Right(
    RequirementEvidence(
      id: 1,
      evidenceType: EvidenceType.image,
      url: 'https://example.com/file.jpg',
    ),
  );

  @override
  Future<Either<Failure, RequirementEvidence>> uploadRequirementEvidence(
    String userId,
    int honorId,
    int requirementId,
    File file, {
    required String mimeType,
  }) async {
    capturedMimeType = mimeType;
    return uploadResult;
  }

  // ── Unused stubs ──────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, List<HonorCategory>>> getHonorCategories(
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
  Future<Either<Failure, Honor>> getHonorById(int honorId,
          {CancelToken? cancelToken}) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, List<UserHonor>>> getUserHonors(String userId,
          {CancelToken? cancelToken}) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Map<String, dynamic>>> getUserHonorStats(
          String userId, {CancelToken? cancelToken}) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, UserHonor>> enrollUserInHonor(
          String userId, int honorId) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, UserHonor>> updateUserHonor(
          String userId, int honorId, Map<String, dynamic> data) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, void>> deleteUserHonor(
          String userId, int honorId) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, UserHonor>> registerUserHonor(
          RegisterUserHonorParams params) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, List<HonorGroup>>> getHonorsGroupedByCategory(
          {CancelToken? cancelToken}) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, List<HonorRequirement>>> getHonorRequirements(
          int honorId, {CancelToken? cancelToken}) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, List<UserHonorRequirementProgress>>>
      getUserHonorProgress(String userId, int honorId,
              {CancelToken? cancelToken}) =>
          throw UnimplementedError();

  @override
  Future<Either<Failure, UserHonorRequirementProgress>>
      updateRequirementProgress({
    required int honorId,
    required int requirementId,
    required bool completed,
    String? notes,
  }) =>
          throw UnimplementedError();

  @override
  Future<Either<Failure, List<UserHonorRequirementProgress>>>
      bulkUpdateRequirementProgress(
              String userId, int honorId, List<Map<String, dynamic>> updates) =>
          throw UnimplementedError();

  @override
  Future<Either<Failure, RequirementEvidence>> addRequirementEvidenceLink(
          String userId, int honorId, int requirementId, String url) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, List<RequirementEvidence>>> getRequirementEvidences(
          String userId, int honorId, int requirementId,
          {CancelToken? cancelToken}) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, void>> deleteRequirementEvidence(
          String userId, int honorId, int requirementId, int evidenceId) =>
      throw UnimplementedError();
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Builds a temp [File] with the given extension so [lookupMimeType] resolves
/// correctly from the path — no actual file on disk needed.
File _tmpFile(String extension) =>
    File('${Directory.systemTemp.path}/test_evidence$extension');

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late _StubHonorsRepository repository;
  late UploadRequirementEvidence usecase;

  setUp(() {
    repository = _StubHonorsRepository();
    usecase = UploadRequirementEvidence(repository);
  });

  group('UploadRequirementEvidence — MIME validation', () {
    test('rejects .exe — returns ValidationFailure, repository NOT called', () async {
      final result = await usecase(UploadRequirementEvidenceParams(
        userId: 'u1',
        honorId: 1,
        requirementId: 1,
        file: _tmpFile('.exe'),
      ));

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<ValidationFailure>()),
        (_) => fail('Expected Left'),
      );
      expect(repository.capturedMimeType, isNull);
    });

    test('rejects .gif — returns ValidationFailure, repository NOT called', () async {
      final result = await usecase(UploadRequirementEvidenceParams(
        userId: 'u1',
        honorId: 1,
        requirementId: 1,
        file: _tmpFile('.gif'),
      ));

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<ValidationFailure>()),
        (_) => fail('Expected Left'),
      );
      expect(repository.capturedMimeType, isNull);
    });

    test('allows .jpg — delegates with mimeType image/jpeg', () async {
      final result = await usecase(UploadRequirementEvidenceParams(
        userId: 'u1',
        honorId: 1,
        requirementId: 1,
        file: _tmpFile('.jpg'),
      ));

      expect(result.isRight(), isTrue);
      expect(repository.capturedMimeType, 'image/jpeg');
    });

    test('allows .png — delegates with mimeType image/png', () async {
      final result = await usecase(UploadRequirementEvidenceParams(
        userId: 'u1',
        honorId: 1,
        requirementId: 1,
        file: _tmpFile('.png'),
      ));

      expect(result.isRight(), isTrue);
      expect(repository.capturedMimeType, 'image/png');
    });

    test('allows .webp — delegates with mimeType image/webp', () async {
      final result = await usecase(UploadRequirementEvidenceParams(
        userId: 'u1',
        honorId: 1,
        requirementId: 1,
        file: _tmpFile('.webp'),
      ));

      expect(result.isRight(), isTrue);
      expect(repository.capturedMimeType, 'image/webp');
    });

    test('allows .pdf — delegates with mimeType application/pdf', () async {
      final result = await usecase(UploadRequirementEvidenceParams(
        userId: 'u1',
        honorId: 1,
        requirementId: 1,
        file: _tmpFile('.pdf'),
      ));

      expect(result.isRight(), isTrue);
      expect(repository.capturedMimeType, 'application/pdf');
    });
  });
}
