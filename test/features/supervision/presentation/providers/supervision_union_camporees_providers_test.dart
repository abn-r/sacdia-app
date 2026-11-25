import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_pending_counts.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_union_camporee.dart';
import 'package:sacdia_app/features/supervision/domain/repositories/supervision_union_camporees_repository.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_union_camporees_providers.dart';

import '../../../../support/riverpod_test_support.dart';

typedef _Unit = Either<Failure, Unit>;

class _FakeRepo implements SupervisionUnionCamporeesRepository {
  Either<Failure, List<SupervisionUnionCamporee>> listResult =
      const Right([SupervisionUnionCamporee(id: 1, name: 'A')]);
  Either<Failure, SupervisionUnionCamporee> detailResult =
      const Right(SupervisionUnionCamporee(id: 1, name: 'A'));
  Either<Failure, SupervisionCamporeePending> pendingResult =
      const Right(SupervisionCamporeePending.empty);
  _Unit decisionResult = const Right(unit);

  int listCalls = 0;
  final detailCalls = <int>[];
  final pendingCalls = <int>[];
  final decisions = <String>[];
  final args = <String, Map<String, Object?>>{};

  _Unit _decide(String name, Map<String, Object?> a) {
    decisions.add(name);
    args[name] = a;
    return decisionResult;
  }

  @override
  Future<Either<Failure, List<SupervisionUnionCamporee>>> getCamporees(
      {RequestCancelToken? cancelToken}) async {
    listCalls++;
    return listResult;
  }

  @override
  Future<Either<Failure, SupervisionUnionCamporee>> getCamporee(int id,
      {RequestCancelToken? cancelToken}) async {
    detailCalls.add(id);
    return detailResult;
  }

  @override
  Future<Either<Failure, SupervisionCamporeePending>> getPending(int id,
      {RequestCancelToken? cancelToken}) async {
    pendingCalls.add(id);
    return pendingResult;
  }

  @override
  Future<_Unit> decideClub(int camporeeId, int id,
          {required bool approve, String? reason}) async =>
      _decide('club', {
        'camporeeId': camporeeId,
        'id': id,
        'approve': approve,
        'reason': reason,
      });

  @override
  Future<_Unit> decideMember(int camporeeId, int id,
          {required bool approve, String? reason}) async =>
      _decide('member', {
        'camporeeId': camporeeId,
        'id': id,
        'approve': approve,
        'reason': reason,
      });

  @override
  Future<_Unit> decidePayment(String paymentId,
          {required bool approve, String? reason}) async =>
      _decide('payment', {
        'paymentId': paymentId,
        'approve': approve,
        'reason': reason,
      });
}

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _FakeRepo repo;
  late int countsBuilds;

  setUp(() {
    repo = _FakeRepo();
    countsBuilds = 0;
  });

  ProviderContainer make({bool listen = true}) {
    final c = createTestContainer(overrides: [
      supervisionUnionCamporeesRepositoryProvider.overrideWithValue(repo),
      supervisionPendingCountsProvider.overrideWith((ref) {
        countsBuilds++;
        return const SupervisionPendingCounts(territoryLevel: 'union');
      }),
    ]);
    if (listen) {
      c.listen(supervisionPendingCountsProvider, (a, b) {});
      c.listen(supervisionCamporeePendingProvider(7), (a, b) {});
      c.listen(supervisionCamporeePendingProvider(8), (a, b) {});
    }
    return c;
  }

  group('read providers', () {
    test('list, detail and pending load through the repository', () async {
      final c = make(listen: false);
      expect((await c.read(supervisionUnionCamporeesProvider.future)).single.id,
          1);
      expect((await c.read(supervisionUnionCamporeeProvider(3).future)).id, 1);
      expect((await c.read(supervisionCamporeePendingProvider(3).future)).total,
          0);
      expect(repo.detailCalls, [3]);
      expect(repo.pendingCalls, [3]);
    });

    test('403 failures surface as forbidden SupervisionLoadException',
        () async {
      const denied = Left<Failure, Never>(AuthFailure(
          message: 'no', code: 403, errorCode: 'GUARD_CLUB_SCOPE_REQUIRED'));
      repo
        ..listResult = denied
        ..detailResult = denied
        ..pendingResult = denied;
      final c = make(listen: false);
      for (final future in [
        c.read(supervisionUnionCamporeesProvider.future),
        c.read(supervisionUnionCamporeeProvider(3).future),
        c.read(supervisionCamporeePendingProvider(3).future),
      ]) {
        await expectLater(
          future,
          throwsA(isA<SupervisionLoadException>()
              .having((e) => e.isForbidden, 'isForbidden', isTrue)
              .having((e) => isForbiddenFailure(e), 'classified', isTrue)),
        );
      }
    });

    test('other failures are not forbidden', () async {
      repo.listResult = const Left(ServerFailure(message: 'boom', code: 500));
      final c = make(listen: false);
      await expectLater(
        c.read(supervisionUnionCamporeesProvider.future),
        throwsA(isA<SupervisionLoadException>()
            .having((e) => e.isForbidden, 'isForbidden', isFalse)
            .having((e) => e.message, 'message', 'boom')),
      );
    });
  });

  group('approval actions', () {
    test('club approve success invalidates pending and hub counts', () async {
      final c = make();
      await _settle();
      expect(repo.pendingCalls, [7, 8]);
      expect(countsBuilds, 1);

      final r = await c
          .read(supervisionCamporeeApprovalActionsProvider)
          .decideClub(7, 3, approve: true);
      await _settle();

      expect(r.ok, isTrue);
      expect(repo.args['club'], {
        'camporeeId': 7,
        'id': 3,
        'approve': true,
        'reason': null,
      });
      // Only the decided camporee is reloaded.
      expect(repo.pendingCalls, [7, 8, 7]);
      expect(countsBuilds, 2);
    });

    test('member and payment decisions trim the reason and invalidate',
        () async {
      final c = make();
      await _settle();
      final actions = c.read(supervisionCamporeeApprovalActionsProvider);

      final m = await actions.decideMember(7, 4,
          approve: false, reason: '  sin seguro  ');
      await _settle();
      expect(m.ok, isTrue);
      expect(repo.args['member']!['reason'], 'sin seguro');
      expect(repo.pendingCalls.where((e) => e == 7).length, 2);

      final p = await actions.decidePayment(7, 'uuid-1',
          approve: false, reason: '   ');
      await _settle();
      expect(p.ok, isTrue);
      expect(repo.args['payment'], {
        'paymentId': 'uuid-1',
        'approve': false,
        'reason': null,
      });
      expect(repo.pendingCalls.where((e) => e == 7).length, 3);
      expect(countsBuilds, 3);
    });

    for (final code in const [
      'CAMPOREE_CLUB_ENROLLMENT_PENDING_NOT_FOUND',
      'CAMPOREE_MEMBER_ENROLLMENT_PENDING_NOT_FOUND',
      'CAMPOREE_PAYMENT_PENDING_NOT_FOUND',
    ]) {
      test('$code fails but still invalidates the stale list', () async {
        repo.decisionResult =
            Left(ServerFailure(message: 'gone', code: 404, errorCode: code));
        final c = make();
        await _settle();
        final actions = c.read(supervisionCamporeeApprovalActionsProvider);

        final r = switch (code) {
          'CAMPOREE_CLUB_ENROLLMENT_PENDING_NOT_FOUND' =>
            await actions.decideClub(7, 1, approve: true),
          'CAMPOREE_MEMBER_ENROLLMENT_PENDING_NOT_FOUND' =>
            await actions.decideMember(7, 1, approve: true),
          _ => await actions.decidePayment(7, 'p', approve: true),
        };
        await _settle();

        expect(r.ok, isFalse);
        expect(r.errorCode, code);
        expect(r.errorMessage, 'gone');
        expect(repo.pendingCalls, [7, 8, 7]);
        expect(countsBuilds, 2);
      });
    }

    test('another failure invalidates nothing and reports forbidden', () async {
      repo.decisionResult = const Left(AuthFailure(
          message: 'no', code: 403, errorCode: 'GUARD_PERMISSION_DENIED'));
      final c = make();
      await _settle();
      final r = await c
          .read(supervisionCamporeeApprovalActionsProvider)
          .decideClub(7, 1, approve: true);
      await _settle();

      expect(r.ok, isFalse);
      expect(r.isForbidden, isTrue);
      expect(r.errorCode, 'GUARD_PERMISSION_DENIED');
      expect(repo.pendingCalls, [7, 8]);
      expect(countsBuilds, 1);
    });

    test('registration closed does not invalidate', () async {
      repo.decisionResult = const Left(ServerFailure(
          message: 'closed',
          code: 400,
          errorCode: 'CAMPOREE_CLUB_REGISTRATION_CLOSED'));
      final c = make();
      await _settle();
      final r = await c
          .read(supervisionCamporeeApprovalActionsProvider)
          .decideClub(7, 1, approve: true);
      await _settle();
      expect(r.errorCode, 'CAMPOREE_CLUB_REGISTRATION_CLOSED');
      expect(repo.pendingCalls, [7, 8]);
    });

    test('actions without any listener do not throw', () async {
      final c = make(listen: false);
      final actions = c.read(supervisionCamporeeApprovalActionsProvider);
      expect((await actions.decideClub(7, 1, approve: true)).ok, isTrue);
      expect((await actions.decideMember(7, 1, approve: false)).ok, isTrue);
      expect((await actions.decidePayment(7, 'p', approve: true)).ok, isTrue);
      repo.decisionResult = const Left(ServerFailure(
          message: 'x',
          code: 404,
          errorCode: 'CAMPOREE_PAYMENT_PENDING_NOT_FOUND'));
      expect((await actions.decidePayment(7, 'p', approve: true)).ok, isFalse);
      expect(repo.decisions.length, 4);
    });
  });
}
