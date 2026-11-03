import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/camporees/domain/repositories/camporees_repository.dart';
import 'package:sacdia_app/features/camporees/presentation/providers/camporees_providers.dart';

import '../../../../support/riverpod_test_support.dart';

/// Removal that takes a moment, like a real network call.
class _SlowRepository extends Fake implements CamporeesRepository {
  _SlowRepository({this.failure});

  final Failure? failure;

  @override
  Future<Either<Failure, void>> removeMember(
      int camporeeId, String userId) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final failure = this.failure;
    return failure == null ? const Right(null) : Left(failure);
  }
}

void main() {
  // The members view only `ref.read`s this notifier, so nothing listens to it.
  // An autoDispose provider is then disposed while the request is in flight,
  // and writing `state` after the await threw.
  test('remove completes when nothing listens to the notifier', () async {
    final container = createTestContainer(overrides: [
      camporeesRepositoryProvider.overrideWithValue(_SlowRepository()),
    ]);

    final ok = await container
        .read(camporeeRemoveMemberNotifierProvider(41).notifier)
        .remove('user-1');

    expect(ok, isTrue);
    final state = container.read(camporeeRemoveMemberNotifierProvider(41));
    expect(state.success, isTrue);
    expect(state.isLoading, isFalse);
  });

  test('a failed removal reports false and keeps the message', () async {
    final container = createTestContainer(overrides: [
      camporeesRepositoryProvider.overrideWithValue(
          _SlowRepository(failure: const ServerFailure(message: 'boom'))),
    ]);

    final ok = await container
        .read(camporeeRemoveMemberNotifierProvider(41).notifier)
        .remove('user-1');

    expect(ok, isFalse);
    expect(
        container.read(camporeeRemoveMemberNotifierProvider(41)).errorMessage,
        'boom');
  });
}
