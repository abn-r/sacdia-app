import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/honors/domain/entities/requirement_evidence.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor_requirement_progress.dart';
import 'package:sacdia_app/features/honors/domain/repositories/honors_repository.dart';
import 'package:sacdia_app/features/honors/domain/usecases/update_requirement_progress.dart';
import 'package:sacdia_app/features/honors/domain/usecases/upload_requirement_evidence.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';

import '../../../../support/riverpod_test_support.dart';

const _evidence = RequirementEvidence(
  id: 1,
  evidenceType: EvidenceType.image,
  url: 'https://cdn/e.jpg',
);

const _progress = UserHonorRequirementProgress(
  requirementId: 5,
  requirementNumber: 1,
  text: 'Requisito',
  completed: true,
);

/// Upload that takes a moment, like a real network call.
class _SlowUpload implements UploadRequirementEvidence {
  _SlowUpload(this.result);

  final Either<Failure, RequirementEvidence> result;

  @override
  HonorsRepository get repository => throw UnimplementedError();

  @override
  Future<Either<Failure, RequirementEvidence>> call(
      UploadRequirementEvidenceParams params) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return result;
  }
}

class _SlowBulkUpdate implements UpdateRequirementProgress {
  _SlowBulkUpdate(this.result);

  final Either<Failure, List<UserHonorRequirementProgress>> result;

  @override
  HonorsRepository get repository => throw UnimplementedError();

  @override
  Future<Either<Failure, List<UserHonorRequirementProgress>>> call(
      UpdateRequirementProgressParams params) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return result;
  }
}

class _FakeAuth extends AuthNotifier {
  @override
  Future<UserEntity?> build() async => const UserEntity(id: 'u1');
}

void main() {
  // The requirement views only `ref.read` these notifiers, so nothing listens
  // to them. An autoDispose provider is then disposed while the request is in
  // flight, and touching `ref`/`state` after the await threw.
  group('RequirementEvidenceActionsNotifier', () {
    test('uploadRequirementEvidence completes when nothing listens', () async {
      final container = createTestContainer(overrides: [
        uploadRequirementEvidenceProvider
            .overrideWithValue(_SlowUpload(const Right(_evidence))),
      ]);

      final ok = await container
          .read(requirementEvidenceActionsNotifierProvider(7).notifier)
          .uploadRequirementEvidence(
            userId: 'u1',
            honorId: 7,
            requirementId: 5,
            file: File('/tmp/e.jpg'),
          );

      expect(ok, isTrue);
      expect(
          container.read(requirementEvidenceActionsNotifierProvider(7)).error,
          isNull);
    });

    test('a failed upload reports false and keeps the message', () async {
      final container = createTestContainer(overrides: [
        uploadRequirementEvidenceProvider.overrideWithValue(
            _SlowUpload(const Left(ServerFailure(message: 'boom')))),
      ]);

      final ok = await container
          .read(requirementEvidenceActionsNotifierProvider(7).notifier)
          .uploadRequirementEvidence(
            userId: 'u1',
            honorId: 7,
            requirementId: 5,
            file: File('/tmp/e.jpg'),
          );

      expect(ok, isFalse);
      expect(
          container.read(requirementEvidenceActionsNotifierProvider(7)).error,
          'boom');
    });
  });

  group('RequirementProgressNotifier', () {
    test('bulkUpdate completes when nothing listens', () async {
      final container = createTestContainer(overrides: [
        authNotifierProvider.overrideWith(_FakeAuth.new),
        updateRequirementProgressProvider
            .overrideWithValue(_SlowBulkUpdate(const Right([_progress]))),
      ]);
      await container.read(authNotifierProvider.future);

      final ok = await container
          .read(requirementProgressNotifierProvider(7).notifier)
          .bulkUpdate([
        {'requirementId': 5, 'completed': true},
      ]);

      expect(ok, isTrue);
      expect(container.read(requirementProgressNotifierProvider(7)).value,
          [_progress]);
    });

    test('a failed update reports false and keeps the message', () async {
      final container = createTestContainer(overrides: [
        authNotifierProvider.overrideWith(_FakeAuth.new),
        updateRequirementProgressProvider.overrideWithValue(
            _SlowBulkUpdate(const Left(ServerFailure(message: 'boom')))),
      ]);
      await container.read(authNotifierProvider.future);

      final ok = await container
          .read(requirementProgressNotifierProvider(7).notifier)
          .bulkUpdate([
        {'requirementId': 5, 'completed': true},
      ]);

      expect(ok, isFalse);
      expect(
          container.read(requirementProgressNotifierProvider(7)).error, 'boom');
    });
  });
}
