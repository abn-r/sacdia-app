import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';
import 'package:sacdia_app/features/honors/domain/repositories/honors_repository.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
import '../../../../support/riverpod_test_support.dart';

/// Only [deleteUserHonor] is exercised; any other call fails the test.
class _AbandonRepository implements HonorsRepository {
  _AbandonRepository({this.failure});

  final Failure? failure;
  final calls = <(String, int)>[];

  @override
  Future<Either<Failure, void>> deleteUserHonor(
    String userId,
    int honorId,
  ) async {
    calls.add((userId, honorId));
    final failure = this.failure;
    if (failure != null) return Left(failure);
    return const Right(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

UserHonor _enrolled() => UserHonor(
      id: 77,
      honorId: 7,
      userId: 'user-1',
      completionMode: HonorCompletionMode.inApp,
      validationStatus: 'IN_PROGRESS',
      date: DateTime(2026, 6, 11),
    );

void main() {
  test('abandons the honor and drops it from the enrolled state', () async {
    final repository = _AbandonRepository();
    var serverHonors = [_enrolled()];
    final container = createTestContainer(
      overrides: [
        honorsRepositoryProvider.overrideWithValue(repository),
        activeHonorCatalogClubTypeIdProvider.overrideWith(
          (ref) => const AsyncValue.data(null),
        ),
        userHonorsProvider.overrideWith((ref) async => serverHonors),
      ],
    );

    final sub = container.listen(userHonorForHonorProvider(7), (_, __) {});
    addTearDown(sub.close);
    await container.read(userHonorsProvider.future);
    // A work-mode override from earlier in the session must not resurrect it.
    container.read(honorCompletionModeOverrideProvider.notifier).state = {
      7: _enrolled(),
    };
    expect(container.read(userHonorForHonorProvider(7)), isNotNull);

    serverHonors = const [];
    final success = await container
        .read(honorAbandonActionsNotifierProvider.notifier)
        .abandon(userId: 'user-1', honorId: 7);
    await container.read(userHonorsProvider.future);

    expect(success, isTrue);
    expect(repository.calls, [('user-1', 7)]);
    expect(container.read(honorCompletionModeOverrideProvider), isEmpty);
    expect(container.read(userHonorForHonorProvider(7)), isNull);
  });

  test('reports failure and keeps the enrollment', () async {
    final repository = _AbandonRepository(
      failure: const ServerFailure(message: 'blocked'),
    );
    final container = createTestContainer(
      overrides: [
        honorsRepositoryProvider.overrideWithValue(repository),
        activeHonorCatalogClubTypeIdProvider.overrideWith(
          (ref) => const AsyncValue.data(null),
        ),
        userHonorsProvider.overrideWith((ref) async => [_enrolled()]),
      ],
    );

    final sub = container.listen(
      honorAbandonActionsNotifierProvider,
      (_, __) {},
    );
    addTearDown(sub.close);
    await container.read(userHonorsProvider.future);

    final success = await container
        .read(honorAbandonActionsNotifierProvider.notifier)
        .abandon(userId: 'user-1', honorId: 7);

    expect(success, isFalse);
    expect(
        container.read(honorAbandonActionsNotifierProvider).hasError, isTrue);
    expect(container.read(userHonorForHonorProvider(7)), isNotNull);
  });

  test('only honors outside review and approval can be abandoned', () {
    UserHonor withStatus(String status) => UserHonor(
          id: 1,
          honorId: 7,
          userId: 'user-1',
          validationStatus: status,
          date: DateTime(2026, 6, 11),
        );

    expect(withStatus('IN_PROGRESS').canAbandon, isTrue);
    expect(withStatus('REJECTED').canAbandon, isTrue);
    expect(withStatus('PENDING_REVIEW').canAbandon, isFalse);
    expect(withStatus('APPROVED').canAbandon, isFalse);
  });
}
