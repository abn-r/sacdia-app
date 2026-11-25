import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_report.dart';
import 'package:sacdia_app/features/supervision/domain/repositories/supervision_reports_repository.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_reports_providers.dart';

import '../../../../support/riverpod_test_support.dart';

const SupervisionPeriodKey _period = (year: 2026, month: 3);

SupervisionClubCompliance _club(int id) =>
    SupervisionClubCompliance(clubId: id, clubName: 'Club $id');

SupervisionCompliancePage _compliancePage(
  List<SupervisionClubCompliance> clubs, {
  int page = 1,
  int? total,
  bool? hasMore,
}) {
  final t = total ?? clubs.length;
  return SupervisionCompliancePage(
    totals: const SupervisionReportCounts(expected: 5, submitted: 2),
    clubCount: t,
    clubs: clubs,
    page: page,
    total: t,
    hasMore: hasMore ?? clubs.length < t,
  );
}

SupervisionMonthlyReport _report(String id) =>
    SupervisionMonthlyReport(id: id, clubName: 'Club $id');

SupervisionReportPage _reportPage(
  List<SupervisionMonthlyReport> items, {
  int page = 1,
  int? total,
  bool? hasMore,
}) {
  final t = total ?? items.length;
  return SupervisionReportPage(
    items: items,
    page: page,
    total: t,
    hasMore: hasMore ?? items.length < t,
  );
}

class _FakeRepo implements SupervisionReportsRepository {
  final complianceCalls =
      <({SupervisionPeriodKey period, int page, int limit})>[];
  final reportCalls = <({SupervisionPeriodKey period, int page, int limit})>[];

  Future<Either<Failure, SupervisionCompliancePage>> Function(int page)
      onCompliance = (_) async => Right(_compliancePage([_club(1)]));
  Future<Either<Failure, SupervisionReportPage>> Function(int page) onReports =
      (_) async => Right(_reportPage([_report('a')]));
  Future<Either<Failure, SupervisionReportPeriods>> Function() onPeriods =
      () async => const Right(SupervisionReportPeriods());

  @override
  Future<Either<Failure, SupervisionReportPeriods>> getPeriods({
    RequestCancelToken? cancelToken,
  }) =>
      onPeriods();

  @override
  Future<Either<Failure, SupervisionCompliancePage>> getCompliance({
    required SupervisionPeriodKey period,
    required int page,
    required int limit,
    RequestCancelToken? cancelToken,
  }) {
    complianceCalls.add((period: period, page: page, limit: limit));
    return onCompliance(page);
  }

  @override
  Future<Either<Failure, SupervisionReportPage>> getReports({
    required SupervisionPeriodKey period,
    required int page,
    required int limit,
    RequestCancelToken? cancelToken,
  }) {
    reportCalls.add((period: period, page: page, limit: limit));
    return onReports(page);
  }

  @override
  Future<Either<Failure, String>> downloadReportPdf(
    String reportId, {
    RequestCancelToken? cancelToken,
  }) async =>
      Right('/tmp/$reportId.pdf');
}

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _FakeRepo repo;

  setUp(() => repo = _FakeRepo());

  ProviderContainer make() => createTestContainer(overrides: [
        supervisionReportsRepositoryProvider.overrideWithValue(repo),
      ]);

  group('periods provider', () {
    test('returns the periods', () async {
      repo.onPeriods = () async => const Right(SupervisionReportPeriods(
            started: [SupervisionReportPeriod(year: 2026, month: 3)],
          ));
      final c = make();
      final periods = await c.read(supervisionReportPeriodsProvider.future);
      expect(periods.started.single.month, 3);
    });

    test('failure becomes a SupervisionLoadException; 403 is forbidden',
        () async {
      repo.onPeriods =
          () async => const Left(AuthFailure(message: 'nope', code: 403));
      final c = make();
      await expectLater(
        c.read(supervisionReportPeriodsProvider.future),
        throwsA(isA<SupervisionLoadException>()
            .having((e) => e.isForbidden, 'isForbidden', true)
            .having((e) => e.message, 'message', 'nope')),
      );
    });

    test('other failures are not forbidden', () async {
      repo.onPeriods =
          () async => const Left(ServerFailure(message: 'boom', code: 500));
      final c = make();
      await expectLater(
        c.read(supervisionReportPeriodsProvider.future),
        throwsA(isA<SupervisionLoadException>()
            .having((e) => e.isForbidden, 'isForbidden', false)),
      );
    });
  });

  group('compliance notifier', () {
    test('build loads page 1 with the period and page size', () async {
      repo.onCompliance =
          (_) async => Right(_compliancePage([_club(1), _club(2)], total: 120));
      final c = make();
      c.listen(supervisionComplianceProvider(_period), (a, b) {});
      expect(c.read(supervisionComplianceProvider(_period)).isLoading, isTrue);
      await _settle();
      final s = c.read(supervisionComplianceProvider(_period));
      expect(s.isLoading, isFalse);
      expect(s.clubs.map((e) => e.clubId), [1, 2]);
      expect(s.totals?.expected, 5);
      expect(s.total, 120);
      expect(s.hasMore, isTrue);
      expect(repo.complianceCalls.single,
          (period: _period, page: 1, limit: kSupervisionCompliancePageSize));
    });

    test('loadMore appends and skips duplicates', () async {
      repo.onCompliance = (page) async => page == 1
          ? Right(_compliancePage([_club(1), _club(2)], total: 4))
          : Right(_compliancePage([_club(2), _club(3)],
              page: 2, total: 4, hasMore: false));
      final c = make();
      c.listen(supervisionComplianceProvider(_period), (a, b) {});
      await _settle();
      final notifier = c.read(supervisionComplianceProvider(_period).notifier);
      await notifier.loadMore();
      final s = c.read(supervisionComplianceProvider(_period));
      expect(s.clubs.map((e) => e.clubId), [1, 2, 3]);
      expect(s.hasMore, isFalse);
      expect(repo.complianceCalls.last.page, 2);
      await notifier.loadMore();
      expect(repo.complianceCalls, hasLength(2));
    });

    test('loadMore failure keeps items and sets the error', () async {
      repo.onCompliance = (page) async => page == 1
          ? Right(_compliancePage([_club(1)], total: 5))
          : const Left(ServerFailure(message: 'boom', code: 500));
      final c = make();
      c.listen(supervisionComplianceProvider(_period), (a, b) {});
      await _settle();
      await c.read(supervisionComplianceProvider(_period).notifier).loadMore();
      final s = c.read(supervisionComplianceProvider(_period));
      expect(s.clubs, hasLength(1));
      expect(s.isLoadingMore, isFalse);
      expect(s.hasMore, isTrue);
      expect(s.error, isA<SupervisionLoadException>());
    });

    test('first load failure: forbidden error', () async {
      repo.onCompliance =
          (_) async => const Left(AuthFailure(message: 'no', code: 403));
      final c = make();
      c.listen(supervisionComplianceProvider(_period), (a, b) {});
      await _settle();
      final s = c.read(supervisionComplianceProvider(_period));
      expect(s.isLoading, isFalse);
      expect(isForbiddenFailure(s.error!), isTrue);
    });

    test('refresh keeps clubs visible while loading', () async {
      final c = make();
      c.listen(supervisionComplianceProvider(_period), (a, b) {});
      await _settle();
      repo.onCompliance = (_) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return Right(_compliancePage([_club(9)]));
      };
      final future =
          c.read(supervisionComplianceProvider(_period).notifier).refresh();
      final during = c.read(supervisionComplianceProvider(_period));
      expect(during.isLoading, isTrue);
      expect(during.clubs.single.clubId, 1);
      await future;
      expect(c.read(supervisionComplianceProvider(_period)).clubs.single.clubId,
          9);
    });

    test('methods called without listening do not throw', () async {
      repo.onCompliance = (page) async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return Right(_compliancePage([_club(page)], total: 3, hasMore: true));
      };
      final c = make();
      final provider = supervisionComplianceProvider(_period);
      final notifier = c.read(provider.notifier);
      await notifier.refresh();
      await notifier.loadMore();
      expect(c.read(provider).clubs.map((e) => e.clubId), [1, 2]);
    });
  });

  group('monthly reports notifier', () {
    test('build loads page 1 with the period and page size', () async {
      repo.onReports = (_) async =>
          Right(_reportPage([_report('a'), _report('b')], total: 40));
      final c = make();
      c.listen(supervisionMonthlyReportsProvider(_period), (a, b) {});
      expect(
          c.read(supervisionMonthlyReportsProvider(_period)).isLoading, isTrue);
      await _settle();
      final s = c.read(supervisionMonthlyReportsProvider(_period));
      expect(s.items.map((e) => e.id), ['a', 'b']);
      expect(s.total, 40);
      expect(s.hasMore, isTrue);
      expect(repo.reportCalls.single,
          (period: _period, page: 1, limit: kSupervisionReportsPageSize));
    });

    test('loadMore appends, skips duplicates and stops at the end', () async {
      repo.onReports = (page) async => page == 1
          ? Right(_reportPage([_report('a'), _report('b')], total: 3))
          : Right(_reportPage([_report('b'), _report('c')],
              page: 2, total: 3, hasMore: false));
      final c = make();
      c.listen(supervisionMonthlyReportsProvider(_period), (a, b) {});
      await _settle();
      final notifier =
          c.read(supervisionMonthlyReportsProvider(_period).notifier);
      await notifier.loadMore();
      final s = c.read(supervisionMonthlyReportsProvider(_period));
      expect(s.items.map((e) => e.id), ['a', 'b', 'c']);
      expect(s.hasMore, isFalse);
      await notifier.loadMore();
      expect(repo.reportCalls, hasLength(2));
    });

    test('loadMore failure keeps items and sets the error', () async {
      repo.onReports = (page) async => page == 1
          ? Right(_reportPage([_report('a')], total: 5))
          : const Left(ServerFailure(message: 'boom', code: 500));
      final c = make();
      c.listen(supervisionMonthlyReportsProvider(_period), (a, b) {});
      await _settle();
      await c
          .read(supervisionMonthlyReportsProvider(_period).notifier)
          .loadMore();
      final s = c.read(supervisionMonthlyReportsProvider(_period));
      expect(s.items, hasLength(1));
      expect(s.error, isA<SupervisionLoadException>());
      expect(s.isLoadingMore, isFalse);
    });

    test('refresh keeps items visible while loading', () async {
      final c = make();
      c.listen(supervisionMonthlyReportsProvider(_period), (a, b) {});
      await _settle();
      repo.onReports = (_) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return Right(_reportPage([_report('z')]));
      };
      final future =
          c.read(supervisionMonthlyReportsProvider(_period).notifier).refresh();
      final during = c.read(supervisionMonthlyReportsProvider(_period));
      expect(during.isLoading, isTrue);
      expect(during.items.single.id, 'a');
      await future;
      expect(c.read(supervisionMonthlyReportsProvider(_period)).items.single.id,
          'z');
    });

    test('methods called without listening do not throw', () async {
      repo.onReports = (page) async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return Right(SupervisionReportPage(
          items: [_report('r$page')],
          page: page,
          total: 3,
          hasMore: true,
        ));
      };
      final c = make();
      final provider = supervisionMonthlyReportsProvider(_period);
      final notifier = c.read(provider.notifier);
      await notifier.refresh();
      await notifier.loadMore();
      expect(c.read(provider).items.map((e) => e.id), ['r1', 'r2']);
    });
  });

  test('download goes through the repository', () async {
    final c = make();
    final result = await c
        .read(supervisionReportsRepositoryProvider)
        .downloadReportPdf('abc');
    expect(result, const Right<Failure, String>('/tmp/abc.pdf'));
  });
}
