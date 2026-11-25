import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/authorization_stale.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/features/supervision/data/datasources/supervision_clubs_remote_data_source.dart';
import 'package:sacdia_app/features/supervision/data/repositories/supervision_clubs_repository_impl.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_club.dart';

const _profile = SupervisionClubProfile(
  id: 1,
  name: 'Orion',
  active: true,
  description: null,
  address: null,
  churchName: '',
  districtName: '',
  localFieldName: '',
  sections: [],
);
const _overview = SupervisionClubOverview(
  attendanceAverage: 90,
  activeMembers: 3,
  investedThisYear: 1,
  pendingRequests: 0,
  upcomingEvents: [],
);
const _leadership = SupervisionClubLeadership(
  director: null,
  deputies: [],
  secretaries: [],
);

class _Fake implements SupervisionClubsRemoteDataSource {
  Future<SupervisionClubProfile> Function() onClub = () async => _profile;
  Future<SupervisionClubOverview> Function() onOverview = () async => _overview;
  Future<SupervisionClubLeadership> Function() onLeadership =
      () async => _leadership;

  @override
  Future<SupervisionClubProfile> getClub(int clubId,
          {CancelToken? cancelToken}) =>
      onClub();

  @override
  Future<SupervisionClubOverview> getOverview(int clubId,
          {CancelToken? cancelToken}) =>
      onOverview();

  @override
  Future<SupervisionClubLeadership> getLeadership(int clubId,
          {CancelToken? cancelToken}) =>
      onLeadership();

  @override
  Future<SupervisionClubPage> getClubs({
    required SupervisionClubActiveFilter filter,
    required String search,
    required int page,
    required int limit,
    CancelToken? cancelToken,
  }) async =>
      throw ServerException(message: 'boom', code: 500);
}

void main() {
  late _Fake ds;
  late SupervisionClubsRepositoryImpl repo;

  setUp(() {
    ds = _Fake();
    repo = SupervisionClubsRepositoryImpl(remoteDataSource: ds);
  });

  test('summary with all three parts', () async {
    final r = await repo.getClubSummary(1);
    final s = r.getOrElse(() => throw StateError('failed'));
    expect(s.profile, _profile);
    expect(s.overview, _overview);
    expect(s.leadership, _leadership);
  });

  test('profile failure fails the whole call', () async {
    ds.onClub = () async => throw ServerException(
        message: 'no', code: 404, errorCode: 'CLUB_NOT_FOUND');
    final r = await repo.getClubSummary(1);
    r.fold((f) {
      expect(f, isA<ServerFailure>());
      expect(f.errorCode, 'CLUB_NOT_FOUND');
    }, (_) => fail('expected failure'));
  });

  test('403 on profile stays forbidden', () async {
    ds.onClub = () async => throw AuthException(
        message: 'denied', code: 403, errorCode: 'GUARD_CLUB_SCOPE_REQUIRED');
    final r = await repo.getClubSummary(1);
    r.fold((f) {
      expect(f, isA<AuthFailure>());
      expect(isForbiddenFailure(f), isTrue);
    }, (_) => fail('expected failure'));
  });

  test('overview failure nulls only the overview', () async {
    ds.onOverview = () async => throw ServerException(message: 'x');
    final s = (await repo.getClubSummary(1)).getOrElse(() => throw 'f');
    expect(s.overview, isNull);
    expect(s.leadership, _leadership);
    expect(s.profile, _profile);
  });

  test('leadership failure (even 403) nulls only the leadership', () async {
    ds.onLeadership = () async => throw AuthException(message: 'x', code: 403);
    final s = (await repo.getClubSummary(1)).getOrElse(() => throw 'f');
    expect(s.leadership, isNull);
    expect(s.overview, _overview);
  });

  test('profile failure with failing secondary parts does not leak errors',
      () async {
    ds.onClub = () async => throw ServerException(message: 'x');
    ds.onOverview = () async => throw ServerException(message: 'y');
    ds.onLeadership = () async => throw ServerException(message: 'z');
    expect((await repo.getClubSummary(1)).isLeft(), isTrue);
  });

  test('authorization-stale in a secondary part propagates', () async {
    ds.onOverview = () async => throw AuthException(
        message: 'stale', code: 403, errorCode: kAuthorizationStaleCode);
    final r = await repo.getClubSummary(1);
    r.fold((f) {
      expect(f.errorCode, kAuthorizationStaleCode);
      expect(isForbiddenFailure(f), isFalse);
    }, (_) => fail('expected failure'));
  });

  test('cancellation in a secondary part propagates', () async {
    ds.onLeadership = () async => throw DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.cancel);
    expect((await repo.getClubSummary(1)).isLeft(), isTrue);
  });

  test('getClubs maps exceptions to failures', () async {
    final r = await repo.getClubs(
        filter: SupervisionClubActiveFilter.all,
        search: '',
        page: 1,
        limit: 25);
    r.fold((f) => expect(f, isA<ServerFailure>()), (_) => fail('failure'));
  });
}
