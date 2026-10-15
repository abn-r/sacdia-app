import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/investiture_requests/domain/entities/investiture_resolution.dart';
import 'package:sacdia_app/features/investiture_requests/domain/entities/own_investiture_entry.dart';
import 'package:sacdia_app/features/investiture_requests/domain/entities/person_status.dart';
import 'package:sacdia_app/features/investiture_requests/presentation/providers/investiture_requests_providers.dart';

import 'fake_investiture_requests_repository.dart';

const _query = SectionYearQuery(sectionId: 4, yearId: 9);

ProviderContainer _container(FakeInvestitureRequestsRepository repo) {
  final container = ProviderContainer(
    overrides: [
      investitureRequestsRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('read providers', () {
    test('presentationContextProvider returns the context', () async {
      final repo = FakeInvestitureRequestsRepository();
      final container = _container(repo);

      final ctx =
          await container.read(presentationContextProvider(_query).future);

      expect(ctx.clubSectionId, 4);
      expect(ctx.window.openToday, isTrue);
    });

    test('a Left in a read provider surfaces the failure message', () async {
      final repo = FakeInvestitureRequestsRepository()
        ..readFailure = const ServerFailure(message: 'boom');
      final container = _container(repo);

      await expectLater(
        container.read(presentationContextProvider(_query).future),
        throwsA(isA<Failure>().having((f) => f.message, 'message', 'boom')),
      );
    });

    test('SectionYearQuery is value-equal', () {
      expect(
        const SectionYearQuery(sectionId: 4, yearId: 9),
        const SectionYearQuery(sectionId: 4, yearId: 9),
      );
    });

    test('history, yearbook and authorizer providers return repository data',
        () async {
      final repo = FakeInvestitureRequestsRepository()
        ..ownHistory = [
          OwnInvestitureEntry(
            personId: 'p1',
            userId: 'u1',
            classId: 3,
            clubSectionId: 4,
            ecclesiasticalYearId: 9,
            investitureDate: DateTime(2026, 11, 15),
            status: PersonStatus.invested,
          ),
        ];
      final container = _container(repo);

      expect(
        (await container.read(ownInvestitureHistoryProvider.future))
            .single
            .status,
        PersonStatus.invested,
      );
      expect(
        await container.read(sectionInvestitureHistoryProvider(4).future),
        isEmpty,
      );
      expect(await container.read(sectionYearbookProvider(4).future), isEmpty);
      expect(
        await container.read(authorizerRequestsProvider(9).future),
        isEmpty,
      );
      expect(
        (await container.read(authorizerRequestProvider('r1').future))
            .requestId,
        'r1',
      );
    });
  });

  group('PresentNotifier', () {
    test('submit goes through isLoading, then success, and invalidates reads',
        () async {
      final repo = FakeInvestitureRequestsRepository();
      final container = _container(repo);
      // Mantener vivos los providers autoDispose para observar la invalidación.
      container.listen(presentationContextProvider(_query), (_, __) {});
      container.listen(openRequestProvider(_query), (_, __) {});
      await container.read(presentationContextProvider(_query).future);
      await container.read(openRequestProvider(_query).future);
      expect(repo.contextCalls, 1);
      expect(repo.openRequestCalls, 1);

      final states = <RequestActionState>[];
      container.listen(
        presentNotifierProvider(_query),
        (_, next) => states.add(next),
        fireImmediately: false,
      );

      final ok =
          await container.read(presentNotifierProvider(_query).notifier).submit(
        investitureDate: DateTime(2026, 11, 5),
        enrollmentIds: const [11, 12],
      );
      await container.read(presentationContextProvider(_query).future);
      await container.read(openRequestProvider(_query).future);

      expect(ok, isTrue);
      expect(states.first.isLoading, isTrue);
      expect(states.last.isLoading, isFalse);
      expect(states.last.success, isTrue);
      expect(states.last.errorMessage, isNull);
      expect(repo.lastArgs!['sectionId'], 4);
      expect(repo.lastArgs!['yearId'], 9);
      expect(repo.lastArgs!['enrollmentIds'], [11, 12]);
      expect(repo.contextCalls, 2);
      expect(repo.openRequestCalls, 2);
    });

    test('a Left(ServerFailure) leaves errorMessage and returns false',
        () async {
      final repo = FakeInvestitureRequestsRepository()
        ..writeFailure = const ServerFailure(message: 'msg');
      final container = _container(repo);

      final ok =
          await container.read(presentNotifierProvider(_query).notifier).submit(
        investitureDate: DateTime(2026, 11, 5),
        enrollmentIds: const [11],
      );

      final state = container.read(presentNotifierProvider(_query));
      expect(ok, isFalse);
      expect(state.errorMessage, 'msg');
      expect(state.isLoading, isFalse);
      expect(state.success, isFalse);
    });
  });

  group('other action notifiers', () {
    test('addPeople, remove and changeDates call the repository', () async {
      final repo = FakeInvestitureRequestsRepository();
      final container = _container(repo);

      expect(
        await container.read(addPeopleNotifierProvider(_query).notifier).submit(
          requestId: 'r1',
          investitureDate: DateTime(2026, 11, 5),
          enrollmentIds: const [13],
        ),
        isTrue,
      );
      expect(
        await container
            .read(removePersonNotifierProvider(_query).notifier)
            .submit(
              requestId: 'r1',
              personId: 'p1',
            ),
        isTrue,
      );
      expect(
        await container
            .read(changeDatesNotifierProvider(_query).notifier)
            .submit(
          requestId: 'r1',
          investitureDate: DateTime(2026, 11, 20),
          personIds: const ['p1'],
        ),
        isTrue,
      );
      expect(repo.calls, ['addPeople', 'removePerson', 'changeDates']);
    });
  });

  group('ResolveNotifier', () {
    test('submit stores the resolution and invalidates authorizer reads',
        () async {
      final repo = FakeInvestitureRequestsRepository();
      final container = _container(repo);
      container.listen(authorizerRequestsProvider(9), (_, __) {});
      await container.read(authorizerRequestsProvider(9).future);
      expect(repo.authorizerListCalls, 1);

      final ok =
          await container.read(resolveNotifierProvider('r1').notifier).submit(
        invest: const [InvestDecision(personId: 'p1')],
        reject: const [RejectDecision(personId: 'p2', reason: 'x')],
      );
      await container.read(authorizerRequestsProvider(9).future);

      final state = container.read(resolveNotifierProvider('r1'));
      expect(ok, isTrue);
      expect(state.success, isTrue);
      expect(state.resolution?.requestId, 'r1');
      expect(repo.lastArgs!['invest'], hasLength(1));
      expect(repo.authorizerListCalls, 2);
    });

    test('a failure keeps errorMessage and no resolution', () async {
      final repo = FakeInvestitureRequestsRepository()
        ..writeFailure = const ServerFailure(message: 'nope');
      final container = _container(repo);

      final ok = await container
          .read(resolveNotifierProvider('r1').notifier)
          .submit(invest: const [InvestDecision(personId: 'p1')]);

      final state = container.read(resolveNotifierProvider('r1'));
      expect(ok, isFalse);
      expect(state.errorMessage, 'nope');
      expect(state.resolution, isNull);
    });
  });
}
