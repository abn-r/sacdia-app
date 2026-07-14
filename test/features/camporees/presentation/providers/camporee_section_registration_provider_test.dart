import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/models/paginated_result.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_member.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_payment.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_section_registration.dart';
import 'package:sacdia_app/features/camporees/domain/repositories/camporees_repository.dart';
import 'package:sacdia_app/features/camporees/presentation/providers/camporees_providers.dart';

const _camporeeId = 41;

class _FakeCamporeesRepository extends Fake implements CamporeesRepository {
  _FakeCamporeesRepository({
    CamporeeSectionRegistration? contextualRegistration,
  }) : contextualRegistration = contextualRegistration ??
            _registration(CamporeeSectionRegistrationStatus.notEnrolled);

  CamporeeSectionRegistration contextualRegistration;
  Failure? contextualFailure;
  List<Camporee> camporees = const [];
  Camporee detailCamporee = _freshCamporee;
  List<Camporee> Function(int call)? camporeesHandler;
  Future<Either<Failure, CamporeeSectionRegistration>> Function(int call)?
      registerHandler;

  int camporeesCalls = 0;
  int contextualCalls = 0;
  int registerCalls = 0;
  int detailCalls = 0;
  int enrolledClubsCalls = 0;
  int memberListCalls = 0;
  int registeredUserIdsCalls = 0;

  @override
  Future<Either<Failure, List<Camporee>>> getCamporees({
    bool? active,
    RequestCancelToken? cancelToken,
  }) async {
    camporeesCalls += 1;
    return right(camporeesHandler?.call(camporeesCalls) ?? camporees);
  }

  @override
  Future<Either<Failure, CamporeeSectionRegistration>>
      getActiveSectionRegistration(int camporeeId) async {
    contextualCalls += 1;
    final failure = contextualFailure;
    return failure == null ? right(contextualRegistration) : left(failure);
  }

  @override
  Future<Either<Failure, CamporeeSectionRegistration>> registerActiveSection(
    int camporeeId,
  ) async {
    registerCalls += 1;
    return registerHandler?.call(registerCalls) ??
        right(
          _registration(CamporeeSectionRegistrationStatus.registered),
        );
  }

  @override
  Future<Either<Failure, Camporee>> getCamporeeDetail(
    int camporeeId, {
    RequestCancelToken? cancelToken,
  }) async {
    detailCalls += 1;
    return right(detailCamporee);
  }

  @override
  Future<Either<Failure, List<CamporeeEnrolledClub>>> getEnrolledClubs(
    int camporeeId, {
    RequestCancelToken? cancelToken,
  }) async {
    enrolledClubsCalls += 1;
    return right(const []);
  }

  @override
  Future<Either<Failure, PaginatedResult<CamporeeMember>>> getCamporeeMembers(
    int camporeeId, {
    int page = 1,
    int limit = 50,
    String? status,
    RequestCancelToken? cancelToken,
  }) async {
    if (status == null) {
      memberListCalls += 1;
    } else {
      registeredUserIdsCalls += 1;
    }

    return right(
      const PaginatedResult(
        data: <CamporeeMember>[],
        meta: PaginationMeta(
          page: 1,
          limit: 50,
          total: 0,
          totalPages: 1,
          hasNextPage: false,
          hasPreviousPage: false,
        ),
      ),
    );
  }
}

void main() {
  group('camporeeSectionRegistrationProvider', () {
    test('transitions from loading to contextual registration data', () async {
      final repository = _FakeCamporeesRepository();
      final container = _container(repository);
      final values = <AsyncValue<CamporeeSectionRegistration>>[];
      final subscription = container.listen(
        camporeeSectionRegistrationProvider(_camporeeId),
        (_, next) => values.add(next),
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final registration = await container.read(
        camporeeSectionRegistrationProvider(_camporeeId).future,
      );

      expect(values.first, const AsyncLoading<CamporeeSectionRegistration>());
      expect(values.last, AsyncData(registration));
      expect(
          registration.status, CamporeeSectionRegistrationStatus.notEnrolled);
      expect(repository.contextualCalls, 1);
    });

    test('surfaces the repository Failure without converting it to UI text',
        () async {
      const failure = AuthFailure(message: 'session expired', code: 401);
      final repository = _FakeCamporeesRepository()
        ..contextualFailure = failure;
      final container = _container(repository);
      final subscription = container.listen(
        camporeeSectionRegistrationProvider(_camporeeId),
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await expectLater(
        container.read(camporeeSectionRegistrationProvider(_camporeeId).future),
        throwsA(same(failure)),
      );
      expect(
        container.read(camporeeSectionRegistrationProvider(_camporeeId)).error,
        same(failure),
      );
    });
  });

  group('registerCamporeeSectionProvider', () {
    test('refreshes cache-first detail instead of reusing a stale list item',
        () async {
      final response = _registration(
        CamporeeSectionRegistrationStatus.registered,
      );
      final repository = _FakeCamporeesRepository()
        ..camporeesHandler = (call) {
          return call == 1 ? [_staleCamporee] : [_freshCamporee];
        }
        ..registerHandler = (_) async => right(response);
      final container = _container(repository);
      final listSubscription = container.listen(
        camporeesProvider,
        (_, __) {},
        fireImmediately: true,
      );
      final mutationSubscription = container.listen(
        registerCamporeeSectionProvider(_camporeeId),
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(listSubscription.close);
      addTearDown(mutationSubscription.close);

      await container.read(camporeesProvider.future);
      final detailSubscription = container.listen(
        camporeeDetailProvider(_camporeeId),
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(detailSubscription.close);
      final cachedDetail = await container.read(
        camporeeDetailProvider(_camporeeId).future,
      );
      expect(cachedDetail, _staleCamporee);
      expect(repository.detailCalls, 0);
      final listCallsBeforeMutation = repository.camporeesCalls;

      await container
          .read(registerCamporeeSectionProvider(_camporeeId).notifier)
          .register();
      final refreshedDetail = await container.read(
        camporeeDetailProvider(_camporeeId).future,
      );

      expect(repository.camporeesCalls, greaterThan(listCallsBeforeMutation));
      expect(refreshedDetail, _freshCamporee);
    });

    test(
        'waits for the backend, prevents duplicate posts, then refreshes all '
        'participant-enabled data', () async {
      final response = _registration(
        CamporeeSectionRegistrationStatus.registered,
      );
      final backend = Completer<Either<Failure, CamporeeSectionRegistration>>();
      final repository = _FakeCamporeesRepository()
        ..registerHandler = (_) => backend.future;
      final container = _container(repository);
      final harness = await _watchRelatedProviders(container);
      final states = <RegisterCamporeeSectionState>[];
      final mutationSubscription = container.listen(
        registerCamporeeSectionProvider(_camporeeId),
        (_, next) => states.add(next),
        fireImmediately: true,
      );
      addTearDown(mutationSubscription.close);

      final notifier = container.read(
        registerCamporeeSectionProvider(_camporeeId).notifier,
      );
      final firstPost = notifier.register();
      final duplicatePost = notifier.register();

      expect(states.first.status, RegisterCamporeeSectionStatus.idle);
      expect(states.last.status, RegisterCamporeeSectionStatus.loading);
      expect(repository.registerCalls, 1);
      expect(await duplicatePost, isFalse);
      expect(
        container.read(registerCamporeeSectionProvider(_camporeeId)).isLoading,
        isTrue,
      );
      expect(repository.contextualCalls, harness.contextualCalls);

      backend.complete(right(response));

      expect(await firstPost, isTrue);
      expect(
        container.read(registerCamporeeSectionProvider(_camporeeId)),
        RegisterCamporeeSectionState.success(response),
      );
      await _waitUntil(
        () =>
            repository.contextualCalls > harness.contextualCalls &&
            repository.detailCalls > harness.detailCalls &&
            repository.enrolledClubsCalls > harness.enrolledClubsCalls &&
            repository.memberListCalls > harness.memberListCalls &&
            repository.registeredUserIdsCalls > harness.registeredUserIdsCalls,
      );
    });

    for (final status in [
      CamporeeSectionRegistrationStatus.pendingApproval,
      CamporeeSectionRegistrationStatus.rejected,
    ]) {
      test('$status refreshes section context but not participant data',
          () async {
        final response = _registration(status);
        final repository = _FakeCamporeesRepository()
          ..registerHandler = (_) async => right(response);
        final container = _container(repository);
        final harness = await _watchRelatedProviders(container);
        final mutationSubscription = container.listen(
          registerCamporeeSectionProvider(_camporeeId),
          (_, __) {},
          fireImmediately: true,
        );
        addTearDown(mutationSubscription.close);

        final result = await container
            .read(registerCamporeeSectionProvider(_camporeeId).notifier)
            .register();

        expect(result, isTrue);
        expect(response.enablesParticipants, isFalse);
        await _waitUntil(
          () =>
              repository.contextualCalls > harness.contextualCalls &&
              repository.detailCalls > harness.detailCalls &&
              repository.enrolledClubsCalls > harness.enrolledClubsCalls,
        );
        await _flushProviderWork();
        expect(repository.memberListCalls, harness.memberListCalls);
        expect(
          repository.registeredUserIdsCalls,
          harness.registeredUserIdsCalls,
        );
      });
    }

    test('keeps contextual data on failure, exposes Failure, and can retry',
        () async {
      const failure = ServerFailure(message: 'registration failed', code: 503);
      final success = _registration(
        CamporeeSectionRegistrationStatus.approved,
      );
      final repository = _FakeCamporeesRepository()
        ..registerHandler =
            (call) async => call == 1 ? left(failure) : right(success);
      final container = _container(repository);
      final contextualSubscription = container.listen(
        camporeeSectionRegistrationProvider(_camporeeId),
        (_, __) {},
        fireImmediately: true,
      );
      final mutationSubscription = container.listen(
        registerCamporeeSectionProvider(_camporeeId),
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(contextualSubscription.close);
      addTearDown(mutationSubscription.close);
      final contextualData = await container.read(
        camporeeSectionRegistrationProvider(_camporeeId).future,
      );
      final contextualCallsBeforeMutation = repository.contextualCalls;
      final notifier = container.read(
        registerCamporeeSectionProvider(_camporeeId).notifier,
      );

      expect(await notifier.register(), isFalse);

      expect(
        container.read(registerCamporeeSectionProvider(_camporeeId)),
        const RegisterCamporeeSectionState.failure(failure),
      );
      expect(
        container
            .read(camporeeSectionRegistrationProvider(_camporeeId))
            .valueOrNull,
        contextualData,
      );
      expect(repository.contextualCalls, contextualCallsBeforeMutation);

      expect(await notifier.register(), isTrue);
      expect(repository.registerCalls, 2);
      expect(
        container.read(registerCamporeeSectionProvider(_camporeeId)),
        RegisterCamporeeSectionState.success(success),
      );
    });
  });
}

ProviderContainer _container(_FakeCamporeesRepository repository) {
  final container = ProviderContainer(
    overrides: [
      camporeesRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<_ProviderCallSnapshot> _watchRelatedProviders(
  ProviderContainer container,
) async {
  final repository =
      container.read(camporeesRepositoryProvider) as _FakeCamporeesRepository;

  container.listen(
    camporeeSectionRegistrationProvider(_camporeeId),
    (_, __) {},
    fireImmediately: true,
  );
  container.listen(
    camporeeDetailProvider(_camporeeId),
    (_, __) {},
    fireImmediately: true,
  );
  container.listen(
    camporeeEnrolledClubsProvider(_camporeeId),
    (_, __) {},
    fireImmediately: true,
  );
  container.listen(
    camporeeMembersProvider(_camporeeId),
    (_, __) {},
    fireImmediately: true,
  );
  container.listen(
    camporeeRegisteredUserIdsProvider(_camporeeId),
    (_, __) {},
    fireImmediately: true,
  );

  await Future.wait([
    container.read(camporeeSectionRegistrationProvider(_camporeeId).future),
    container.read(camporeeDetailProvider(_camporeeId).future),
    container.read(camporeeEnrolledClubsProvider(_camporeeId).future),
    container.read(camporeeMembersProvider(_camporeeId).future),
    container.read(camporeeRegisteredUserIdsProvider(_camporeeId).future),
  ]);

  return _ProviderCallSnapshot(
    contextualCalls: repository.contextualCalls,
    detailCalls: repository.detailCalls,
    enrolledClubsCalls: repository.enrolledClubsCalls,
    memberListCalls: repository.memberListCalls,
    registeredUserIdsCalls: repository.registeredUserIdsCalls,
  );
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail('Timed out waiting for provider refresh');
}

Future<void> _flushProviderWork() async {
  await Future<void>.delayed(const Duration(milliseconds: 10));
}

class _ProviderCallSnapshot {
  final int contextualCalls;
  final int detailCalls;
  final int enrolledClubsCalls;
  final int memberListCalls;
  final int registeredUserIdsCalls;

  const _ProviderCallSnapshot({
    required this.contextualCalls,
    required this.detailCalls,
    required this.enrolledClubsCalls,
    required this.memberListCalls,
    required this.registeredUserIdsCalls,
  });
}

CamporeeSectionRegistration _registration(
  CamporeeSectionRegistrationStatus status,
) {
  return CamporeeSectionRegistration(
    camporeeId: _camporeeId,
    clubId: 7,
    clubName: 'Central',
    clubSectionId: 19,
    sectionName: 'Pathfinders',
    clubTypeId: 2,
    clubTypeName: 'Pathfinders',
    status: status,
    disposition: CamporeeSectionRegistrationDisposition.open,
    canEnroll: status == CamporeeSectionRegistrationStatus.notEnrolled,
    enrollmentId:
        status == CamporeeSectionRegistrationStatus.notEnrolled ? null : 301,
  );
}

final _staleCamporee = Camporee(
  camporeeId: _camporeeId,
  name: 'Camporee 2026 (stale)',
  startDate: DateTime.utc(2026, 8, 1),
  endDate: DateTime.utc(2026, 8, 3),
  place: 'Field',
  includesAdventurers: true,
  includesPathfinders: true,
  includesMasterGuides: true,
  active: true,
);

final _freshCamporee = Camporee(
  camporeeId: _camporeeId,
  name: 'Camporee 2026 (fresh)',
  startDate: DateTime.utc(2026, 8, 1),
  endDate: DateTime.utc(2026, 8, 3),
  place: 'Updated field',
  includesAdventurers: true,
  includesPathfinders: true,
  includesMasterGuides: true,
  active: true,
);
