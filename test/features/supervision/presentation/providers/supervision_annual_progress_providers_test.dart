import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/providers/riverpod_aliases.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_annual_progress.dart';
import 'package:sacdia_app/features/supervision/domain/repositories/supervision_annual_progress_repository.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_annual_progress_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_providers.dart';
import 'package:sacdia_app/providers/catalogs_provider.dart';
import 'package:sacdia_app/shared/models/catalogs/ecclesiastical_year_model.dart';

import '../../../../support/riverpod_test_support.dart';

const SupervisionAnnualProgressQuery _query = (
  localFieldId: 3,
  clubTypeId: 2,
  yearId: 9,
);

EcclesiasticalYearModel _year(int id, int startYear, {bool active = true}) =>
    EcclesiasticalYearModel(
      ecclesiasticalYearId: id,
      name: '$startYear-${startYear + 1}',
      startDate: DateTime(startYear, 7, 1),
      endDate: DateTime(startYear + 1, 6, 30),
      active: active,
    );

class _FakeRepo implements SupervisionAnnualProgressRepository {
  final calls = <String>[];
  Either<Failure, List<SupervisionTerritoryOption>> unions =
      const Right([SupervisionTerritoryOption(id: 1, name: 'U')]);
  Either<Failure, List<SupervisionTerritoryOption>> fields =
      const Right([SupervisionTerritoryOption(id: 2, name: 'F')]);
  Either<Failure, SupervisionAnnualProgress> progress =
      const Right(SupervisionAnnualProgress(configured: false));

  @override
  Future<Either<Failure, List<SupervisionTerritoryOption>>> getUnions(
    int divisionId, {
    RequestCancelToken? cancelToken,
  }) async {
    calls.add('unions:$divisionId');
    return unions;
  }

  @override
  Future<Either<Failure, List<SupervisionTerritoryOption>>> getLocalFields(
    int unionId, {
    RequestCancelToken? cancelToken,
  }) async {
    calls.add('fields:$unionId');
    return fields;
  }

  @override
  Future<Either<Failure, SupervisionAnnualProgress>> getAnnualProgress(
    SupervisionAnnualProgressQuery query, {
    RequestCancelToken? cancelToken,
  }) async {
    calls.add(
        'progress:${query.localFieldId}/${query.clubTypeId}/${query.yearId}');
    return progress;
  }
}

void main() {
  late _FakeRepo repo;

  setUp(() => repo = _FakeRepo());

  ProviderContainer make({List<Override> extra = const []}) =>
      createTestContainer(overrides: [
        supervisionAnnualProgressRepositoryProvider.overrideWithValue(repo),
        ...extra,
      ]);

  group('read providers', () {
    test('unions and local fields use the family argument', () async {
      final c = make();
      expect((await c.read(supervisionUnionsProvider(5).future)).single.id, 1);
      expect((await c.read(supervisionLocalFieldsProvider(7).future)).single.id,
          2);
      expect(repo.calls, ['unions:5', 'fields:7']);
    });

    test('annual progress passes the query through', () async {
      repo.progress = const Right(SupervisionAnnualProgress(configured: true));
      final c = make();
      final result =
          await c.read(supervisionAnnualProgressProvider(_query).future);
      expect(result.configured, isTrue);
      expect(repo.calls, ['progress:3/2/9']);
    });

    test('failures become SupervisionLoadException (403 forbidden)', () async {
      repo.unions = const Left(AuthFailure(message: 'denied', code: 403));
      repo.fields = const Left(ServerFailure(message: 'boom', code: 500));
      repo.progress = const Left(AuthFailure(message: 'scope', code: 403));
      final c = make();
      await expectLater(
        c.read(supervisionUnionsProvider(1).future),
        throwsA(isA<SupervisionLoadException>()
            .having((e) => e.isForbidden, 'isForbidden', true)),
      );
      await expectLater(
        c.read(supervisionLocalFieldsProvider(1).future),
        throwsA(isA<SupervisionLoadException>()
            .having((e) => e.isForbidden, 'isForbidden', false)),
      );
      await expectLater(
        c.read(supervisionAnnualProgressProvider(_query).future),
        throwsA(isA<SupervisionLoadException>()
            .having((e) => e.message, 'message', 'scope')),
      );
    });
  });

  group('year provider', () {
    test('prefers the current year', () async {
      final c = make(extra: [
        currentEcclesiasticalYearProvider
            .overrideWith((ref) async => _year(5, 2026)),
        ecclesiasticalYearsProvider(true)
            .overrideWith((ref) async => [_year(9, 2030)]),
      ]);
      expect(
          (await c.read(supervisionProgressYearProvider.future))!
              .ecclesiasticalYearId,
          5);
    });

    test('null current year falls back to the newest active one', () async {
      final c = make(extra: [
        currentEcclesiasticalYearProvider.overrideWith((ref) async => null),
        ecclesiasticalYearsProvider(true).overrideWith((ref) async => [
              _year(1, 2023),
              _year(2, 2025),
              _year(3, 2026, active: false),
            ]),
      ]);
      expect(
          (await c.read(supervisionProgressYearProvider.future))!
              .ecclesiasticalYearId,
          2);
    });

    test('current-year failure falls back to the list', () async {
      final c = make(extra: [
        currentEcclesiasticalYearProvider
            .overrideWith((ref) async => throw Exception('boom')),
        ecclesiasticalYearsProvider(true)
            .overrideWith((ref) async => [_year(4, 2024)]),
      ]);
      expect(
          (await c.read(supervisionProgressYearProvider.future))!
              .ecclesiasticalYearId,
          4);
    });

    test('no active year gives null', () async {
      final c = make(extra: [
        currentEcclesiasticalYearProvider.overrideWith((ref) async => null),
        ecclesiasticalYearsProvider(true).overrideWith((ref) async => []),
      ]);
      expect(await c.read(supervisionProgressYearProvider.future), isNull);
    });

    test('both failing throws SupervisionLoadException', () async {
      final c = make(extra: [
        currentEcclesiasticalYearProvider
            .overrideWith((ref) async => throw Exception('first')),
        ecclesiasticalYearsProvider(true)
            .overrideWith((ref) async => throw Exception('second')),
      ]);
      await expectLater(
        c.read(supervisionProgressYearProvider.future),
        // No raw exception text: the screen shows its own localized error.
        throwsA(isA<SupervisionLoadException>()
            .having((e) => e.message, 'message', isEmpty)
            .having((e) => e.isForbidden, 'isForbidden', isFalse)),
      );
    });
  });
}
