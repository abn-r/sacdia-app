import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/post_registration/data/datasources/club_selection_remote_data_source.dart';
import 'package:sacdia_app/features/post_registration/data/datasources/personal_info_remote_data_source.dart';
import 'package:sacdia_app/features/post_registration/domain/repositories/post_registration_repository.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/club_selection_providers.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/personal_info_providers.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/post_registration_flow_providers.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/post_registration_providers.dart';

import '../../support/riverpod_test_support.dart';
import '../family/family_test_harness.dart';

const _slow = Duration(milliseconds: 20);

/// Step 1 call that takes a moment, like a real network call.
class _SlowRepository implements PostRegistrationRepository {
  _SlowRepository(this.result);

  final Either<Failure, void> result;

  @override
  Future<Either<Failure, void>> completeStep1(String userId) async {
    await Future<void>.delayed(_slow);
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _SlowPersonalInfo implements PersonalInfoRemoteDataSource {
  _SlowPersonalInfo({this.error});

  final AppException? error;

  @override
  Future<void> completeStep2(String userId) async {
    await Future<void>.delayed(_slow);
    if (error != null) throw error!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _SlowClubSelection implements ClubSelectionRemoteDataSource {
  _SlowClubSelection({this.error});

  final AppException? error;

  @override
  Future<void> completeStep3({
    required String userId,
    required int countryId,
    required int unionId,
    required int localFieldId,
    required int clubSectionId,
    int? classId,
  }) async {
    await Future<void>.delayed(_slow);
    if (error != null) throw error!;
  }

  @override
  Future<void> completeGuardianOnly({
    required String userId,
    int? countryId,
    int? unionId,
    int? localFieldId,
  }) async {
    await Future<void>.delayed(_slow);
    if (error != null) throw error!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// Builds a container where NOTHING listens to the flow notifier, exactly like
/// the post-registration shell, which only `ref.read`s it.
Future<PostRegistrationFlowNotifier> _notifier({
  Either<Failure, void> step1 = const Right(null),
  AppException? step2Error,
  AppException? step3Error,
}) async {
  final container = createTestContainer(
    overrides: [
      authNotifierProvider.overrideWith(() => FakeAuthNotifier()),
      postRegistrationRepositoryProvider
          .overrideWithValue(_SlowRepository(step1)),
      personalInfoDataSourceProvider
          .overrideWithValue(_SlowPersonalInfo(error: step2Error)),
      clubSelectionDataSourceProvider
          .overrideWithValue(_SlowClubSelection(error: step3Error)),
      selectedCountryProvider.overrideWith((ref) => 25),
      selectedUnionProvider.overrideWith((ref) => 20),
      selectedLocalFieldProvider.overrideWith((ref) => 4),
      selectedClubSectionProvider.overrideWith((ref) => 163),
    ],
  );
  await container.read(authNotifierProvider.future);
  return container.read(postRegistrationFlowNotifierProvider.notifier);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initLocalization);

  // The shell only `ref.read`s this autoDispose notifier. With no listener,
  // Riverpod 3 disposed it while the request was in flight and the `state`
  // write after the await threw: "Continuar" did nothing.
  group('with no listener', () {
    test('completeStep1 completes the step', () async {
      final notifier = await _notifier();

      final result = await notifier.completeStep1();

      expect(result.success, isTrue);
    });

    test('completeStep1 reports a failure instead of throwing', () async {
      final notifier = await _notifier(
        step1: const Left(ServerFailure(message: 'boom')),
      );

      final result = await notifier.completeStep1();

      expect(result.success, isFalse);
      expect(result.errorMessage, isNotNull);
    });

    test('completeStep2 completes the step', () async {
      final notifier = await _notifier();

      final result = await notifier.completeStep2(canReadSensitiveData: false);

      expect(result.success, isTrue);
    });

    test('completeStep2 reports a failure through its catch path', () async {
      final notifier = await _notifier(
        step2Error: ServerException(message: 'x', code: 500),
      );

      final result = await notifier.completeStep2(canReadSensitiveData: false);

      expect(result.success, isFalse);
    });

    test('completeStep3 completes the step', () async {
      final notifier = await _notifier();

      final result = await notifier.completeStep3();

      expect(result.success, isTrue);
    });

    test('completeStep3 reports a conflict', () async {
      final notifier = await _notifier(
        step3Error: ServerException(
          message: 'x',
          code: 409,
          errorCode: 'POST_REG_DUPLICATE_MEMBERSHIP',
        ),
      );

      final result = await notifier.completeStep3();

      expect(result.success, isFalse);
      expect(result.errorCode, 'POST_REG_DUPLICATE_MEMBERSHIP');
    });

    test('completeGuardianOnly completes the step', () async {
      final notifier = await _notifier();

      final result = await notifier.completeGuardianOnly();

      expect(result.success, isTrue);
    });
  });
}
