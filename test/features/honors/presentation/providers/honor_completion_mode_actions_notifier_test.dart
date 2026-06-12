import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor_category.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor_group.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor_requirement.dart';
import 'package:sacdia_app/features/honors/domain/entities/requirement_evidence.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor_requirement_progress.dart';
import 'package:sacdia_app/features/honors/domain/repositories/honors_repository.dart';
import 'package:sacdia_app/features/honors/domain/usecases/register_user_honor.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';

class _StaleCompletionModeRepository implements HonorsRepository {
  int callCount = 0;
  HonorCompletionMode? capturedMode;

  @override
  Future<Either<Failure, UserHonor>> updateHonorCompletionMode({
    required String userId,
    required int honorId,
    required HonorCompletionMode completionMode,
  }) async {
    callCount += 1;
    capturedMode = completionMode;
    return Right(
      UserHonor(
        id: 77,
        honorId: honorId,
        userId: userId,
        completionMode: HonorCompletionMode.undecided,
        validationStatus: 'IN_PROGRESS',
        date: DateTime(2026, 6, 11),
      ),
    );
  }

  @override
  Future<Either<Failure, List<HonorCategory>>> getHonorCategories({
    RequestCancelToken? cancelToken,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, List<Honor>>> getHonors({
    int? categoryId,
    int? clubTypeId,
    int? skillLevel,
    RequestCancelToken? cancelToken,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Honor>> getHonorById(
    int honorId, {
    RequestCancelToken? cancelToken,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, List<UserHonor>>> getUserHonors(
    String userId, {
    RequestCancelToken? cancelToken,
  }) async =>
      const Right<Failure, List<UserHonor>>(<UserHonor>[]);

  @override
  Future<Either<Failure, Map<String, dynamic>>> getUserHonorStats(
    String userId, {
    RequestCancelToken? cancelToken,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, UserHonor>> enrollUserInHonor(
    String userId,
    int honorId,
  ) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, UserHonor>> updateUserHonor(
    String userId,
    int honorId,
    Map<String, dynamic> data,
  ) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, void>> deleteUserHonor(
    String userId,
    int honorId,
  ) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, UserHonor>> registerUserHonor(
    RegisterUserHonorParams params,
  ) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, List<HonorGroup>>> getHonorsGroupedByCategory({
    RequestCancelToken? cancelToken,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, List<HonorRequirement>>> getHonorRequirements(
    int honorId, {
    RequestCancelToken? cancelToken,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, List<UserHonorRequirementProgress>>>
      getUserHonorProgress(
    String userId,
    int honorId, {
    RequestCancelToken? cancelToken,
  }) =>
          throw UnimplementedError();

  @override
  Future<Either<Failure, UserHonorRequirementProgress>>
      updateRequirementProgress({
    required String userId,
    required int honorId,
    required int requirementId,
    required bool completed,
    String? notes,
  }) =>
          throw UnimplementedError();

  @override
  Future<Either<Failure, List<UserHonorRequirementProgress>>>
      bulkUpdateRequirementProgress(
    String userId,
    int honorId,
    List<Map<String, dynamic>> updates,
  ) =>
          throw UnimplementedError();

  @override
  Future<Either<Failure, void>> uploadHonorFile({
    required String userId,
    required int honorId,
    required File file,
    required String fileName,
    HonorFileUploadField uploadField = HonorFileUploadField.images,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, RequirementEvidence>> uploadRequirementEvidence(
    String userId,
    int honorId,
    int requirementId,
    File file, {
    required String mimeType,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, RequirementEvidence>> addRequirementEvidenceLink(
    String userId,
    int honorId,
    int requirementId,
    String url,
  ) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, List<RequirementEvidence>>> getRequirementEvidences(
    String userId,
    int honorId,
    int requirementId, {
    RequestCancelToken? cancelToken,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, void>> deleteRequirementEvidence(
    String userId,
    int honorId,
    int requirementId,
    int evidenceId,
  ) =>
      throw UnimplementedError();
}

void main() {
  test(
    'uses the confirmed mode as effective state when backend returns stale mode',
    () async {
      final repository = _StaleCompletionModeRepository();
      final container = ProviderContainer(
        overrides: [
          honorsRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(
        honorCompletionModeActionsNotifierProvider.notifier,
      );

      final success = await notifier.updateCompletionMode(
        userId: 'user-1',
        honorId: 7,
        completionMode: HonorCompletionMode.external,
      );

      final state = container.read(honorCompletionModeActionsNotifierProvider);

      expect(success, isTrue);
      expect(repository.callCount, 1);
      expect(repository.capturedMode, HonorCompletionMode.external);
      expect(state.valueOrNull?.completionMode, HonorCompletionMode.external);
    },
  );
}
