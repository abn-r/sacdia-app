import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/certifications/domain/repositories/certifications_repository.dart';
import 'package:sacdia_app/features/certifications/presentation/providers/certifications_providers.dart';

import '../../../support/riverpod_test_support.dart';

/// Every mutation takes a moment, like a real network call.
class _SlowRepository implements CertificationsRepository {
  _SlowRepository({this.failure});

  final Failure? failure;

  Future<Either<Failure, T>> _result<T>(T value) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final failure = this.failure;
    return failure == null ? Right(value) : Left(failure);
  }

  @override
  Future<Either<Failure, void>> enrollCertification(
          String userId, int certificationId) =>
      _result<void>(null);

  @override
  Future<Either<Failure, void>> unenrollCertification(
          String userId, int certificationId) =>
      _result<void>(null);

  @override
  Future<Either<Failure, Map<String, dynamic>>> updateSectionProgress(
    String userId,
    int certificationId,
    int moduleId,
    int sectionId,
    bool completed,
  ) =>
      _result<Map<String, dynamic>>(const {});

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  // The certification views only `ref.read` these notifiers, so nothing
  // listens to them. An autoDispose provider is then disposed while the
  // request is in flight, and writing `state` after the await threw.
  group('CertificationEnrollmentNotifier', () {
    test('enroll completes when nothing listens', () async {
      final container = createTestContainer(overrides: [
        certificationsRepositoryProvider.overrideWithValue(_SlowRepository()),
      ]);

      final ok = await container
          .read(certificationEnrollmentNotifierProvider(3).notifier)
          .enroll();

      expect(ok, isTrue);
      final state = container.read(certificationEnrollmentNotifierProvider(3));
      expect(state.success, isTrue);
      expect(state.isLoading, isFalse);
    });

    test('unenroll completes when nothing listens', () async {
      final container = createTestContainer(overrides: [
        certificationsRepositoryProvider.overrideWithValue(_SlowRepository()),
      ]);

      final ok = await container
          .read(certificationEnrollmentNotifierProvider(3).notifier)
          .unenroll();

      expect(ok, isTrue);
      expect(container.read(certificationEnrollmentNotifierProvider(3)).success,
          isTrue);
    });

    test('a failed enroll reports false and keeps the message', () async {
      final container = createTestContainer(overrides: [
        certificationsRepositoryProvider.overrideWithValue(
            _SlowRepository(failure: const ServerFailure(message: 'boom'))),
      ]);

      final ok = await container
          .read(certificationEnrollmentNotifierProvider(3).notifier)
          .enroll();

      expect(ok, isFalse);
      expect(
          container
              .read(certificationEnrollmentNotifierProvider(3))
              .errorMessage,
          'boom');
    });
  });

  group('SectionProgressNotifier', () {
    test('updateSection completes when nothing listens', () async {
      final container = createTestContainer(overrides: [
        certificationsRepositoryProvider.overrideWithValue(_SlowRepository()),
      ]);

      final ok = await container
          .read(sectionProgressNotifierProvider(3).notifier)
          .updateSection(moduleId: 1, sectionId: 2, completed: true);

      expect(ok, isTrue);
      expect(
          container.read(sectionProgressNotifierProvider(3)).success, isTrue);
    });

    test('a failed update reports false and keeps the message', () async {
      final container = createTestContainer(overrides: [
        certificationsRepositoryProvider.overrideWithValue(
            _SlowRepository(failure: const ServerFailure(message: 'boom'))),
      ]);

      final ok = await container
          .read(sectionProgressNotifierProvider(3).notifier)
          .updateSection(moduleId: 1, sectionId: 2, completed: false);

      expect(ok, isFalse);
      expect(container.read(sectionProgressNotifierProvider(3)).errorMessage,
          'boom');
    });
  });
}
