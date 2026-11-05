import 'package:dartz/dartz.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/authorization_stale.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_member.dart';
import 'package:sacdia_app/features/camporees/domain/repositories/camporees_repository.dart';
import 'package:sacdia_app/features/camporees/presentation/providers/camporees_providers.dart';

import '../../../../support/l10n_test_support.dart';
import '../../../../support/riverpod_test_support.dart';

/// Rechazo local del `AuthorizationStaleInterceptor` tal y como llega al
/// notifier: un 403 cuyo `errorCode` es `AUTHORIZATION_STALE`.
const _staleFailure = AuthFailure(
  message: 'Permisos sin verificar',
  code: 403,
  errorCode: kAuthorizationStaleCode,
);

/// 403 real del backend cuando el miembro no tiene seguro vigente.
const _insuranceFailure = ServerFailure(
  message: 'El miembro no cuenta con seguro vigente',
  code: 403,
);

class _Repository extends Fake implements CamporeesRepository {
  _Repository({this.failuresByUserId = const {}});

  /// Fallo a devolver por usuario; el resto se inscribe con éxito.
  final Map<String, Failure> failuresByUserId;

  @override
  Future<Either<Failure, CamporeeMember>> registerMember(
    int camporeeId, {
    required String userId,
    String? camporeeType,
    String? clubName,
    required int insuranceId,
  }) async {
    final failure = failuresByUserId[userId];
    if (failure != null) return Left(failure);
    return Right(CamporeeMember(
      camporeeMemberId: 1,
      userId: userId,
      insuranceVerified: true,
      active: true,
    ));
  }
}

void main() {
  setUpAll(loadSpanishTranslations);

  group('CamporeeRegistrationNotifier.register', () {
    test('a backend 403 is reported as an insurance error', () async {
      final container = createTestContainer(overrides: [
        camporeesRepositoryProvider.overrideWithValue(
          _Repository(failuresByUserId: const {'user-1': _insuranceFailure}),
        ),
      ]);

      final ok = await container
          .read(camporeeRegistrationNotifierProvider(7).notifier)
          .register(userId: 'user-1', insuranceId: 3);

      expect(ok, isFalse);
      final state = container.read(camporeeRegistrationNotifierProvider(7));
      expect(state.isInsuranceError, isTrue);
      expect(state.errorMessage, _insuranceFailure.message);
      expect(state.isLoading, isFalse);
    });

    test('the stale-authorization rejection is not an insurance error',
        () async {
      final container = createTestContainer(overrides: [
        camporeesRepositoryProvider.overrideWithValue(
          _Repository(failuresByUserId: const {'user-1': _staleFailure}),
        ),
      ]);

      final ok = await container
          .read(camporeeRegistrationNotifierProvider(7).notifier)
          .register(userId: 'user-1', insuranceId: 3);

      expect(ok, isFalse);
      final state = container.read(camporeeRegistrationNotifierProvider(7));
      expect(state.isInsuranceError, isFalse);
      expect(state.errorMessage, tr('errors.authorization_stale'));
      expect(state.success, isFalse);
      expect(state.isLoading, isFalse);
    });
  });

  group('CamporeeRegistrationNotifier.registerMany', () {
    test('only the stale rejection never flags an insurance error', () async {
      final container = createTestContainer(overrides: [
        camporeesRepositoryProvider.overrideWithValue(
          _Repository(failuresByUserId: const {
            'user-1': _staleFailure,
            'user-2': _staleFailure,
          }),
        ),
      ]);

      final result = await container
          .read(camporeeRegistrationNotifierProvider(7).notifier)
          .registerMany(insuranceIdsByUserId: const {'user-1': 3, 'user-2': 4});

      expect(result.successCount, 0);
      expect(result.failureCount, 2);
      expect(result.firstErrorMessage, tr('errors.authorization_stale'));
      final state = container.read(camporeeRegistrationNotifierProvider(7));
      expect(state.isInsuranceError, isFalse);
      expect(state.errorMessage, tr('errors.authorization_stale'));
    });

    test('a real insurance 403 next to a stale rejection still flags it',
        () async {
      final container = createTestContainer(overrides: [
        camporeesRepositoryProvider.overrideWithValue(
          _Repository(failuresByUserId: const {
            'user-1': _staleFailure,
            'user-2': _insuranceFailure,
          }),
        ),
      ]);

      final result = await container
          .read(camporeeRegistrationNotifierProvider(7).notifier)
          .registerMany(insuranceIdsByUserId: const {
        'user-1': 3,
        'user-2': 4,
        'user-3': 5,
      });

      expect(result.successCount, 1);
      expect(result.failureCount, 2);
      final state = container.read(camporeeRegistrationNotifierProvider(7));
      expect(state.isInsuranceError, isTrue);
      expect(state.success, isFalse);
    });
  });
}
