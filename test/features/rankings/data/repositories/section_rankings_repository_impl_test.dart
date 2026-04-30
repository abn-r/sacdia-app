import 'package:flutter_test/flutter_test.dart';

import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/network/network_info.dart';
import 'package:sacdia_app/features/rankings/data/datasources/rankings_remote_data_source.dart';
import 'package:sacdia_app/features/rankings/data/models/member_ranking_dto.dart';
import 'package:sacdia_app/features/rankings/data/models/section_ranking_dto.dart';
import 'package:sacdia_app/features/rankings/data/repositories/section_rankings_repository_impl.dart';

// ── Stubs ─────────────────────────────────────────────────────────────────────

class _StubDataSource implements RankingsRemoteDataSource {
  Object? getSectionRankingsResult;
  Object? getSectionMembersResult;

  @override
  Future<MyRankingResponseDto> getMyRanking(
    int yearId, {
    cancelToken,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<SectionRankingDto>> getSectionRankings({
    required int yearId,
    int? clubId,
    int page = 1,
    int limit = 20,
    cancelToken,
  }) async {
    final r = getSectionRankingsResult;
    if (r is Exception) throw r;
    return r as List<SectionRankingDto>;
  }

  @override
  Future<List<SectionMemberDto>> getSectionMembers(
    int sectionId,
    int yearId, {
    cancelToken,
  }) async {
    final r = getSectionMembersResult;
    if (r is Exception) throw r;
    return r as List<SectionMemberDto>;
  }
}

class _AlwaysConnected implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;
}

class _NeverConnected implements NetworkInfo {
  @override
  Future<bool> get isConnected async => false;
}

// ── Fixtures ──────────────────────────────────────────────────────────────────

SectionRankingDto _sectionDto({
  int clubSectionId = 10,
  String sectionName = 'Sección A',
  double? compositeScorePct = 80.0,
  int? rankPosition = 1,
  int activeEnrollmentCount = 12,
}) {
  return SectionRankingDto(
    clubSectionId: clubSectionId,
    sectionName: sectionName,
    compositeScorePct: compositeScorePct,
    rankPosition: rankPosition,
    activeEnrollmentCount: activeEnrollmentCount,
  );
}

SectionMemberDto _memberDto({
  int enrollmentId = 1,
  String userId = 'user-xyz',
  String memberName = 'Maria Lopez',
  double? compositeScorePct = 90.0,
  int? rankPosition = 1,
}) {
  return SectionMemberDto(
    enrollmentId: enrollmentId,
    userId: userId,
    memberName: memberName,
    compositeScorePct: compositeScorePct,
    rankPosition: rankPosition,
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late _StubDataSource dataSource;
  late SectionRankingsRepositoryImpl repository;

  setUp(() {
    dataSource = _StubDataSource();
    repository = SectionRankingsRepositoryImpl(
      remoteDataSource: dataSource,
      networkInfo: _AlwaysConnected(),
    );
  });

  // ── getSectionRankings ────────────────────────────────────────────────────────

  group('SectionRankingsRepositoryImpl.getSectionRankings', () {
    test('returns Right(List<SectionRanking>) on 200 OK', () async {
      dataSource.getSectionRankingsResult = [
        _sectionDto(),
        _sectionDto(
          clubSectionId: 11,
          sectionName: 'Sección B',
          compositeScorePct: 70.0,
          rankPosition: 2,
        ),
      ];

      final result = await repository.getSectionRankings(yearId: 5);

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected Right'),
        (sections) {
          expect(sections, hasLength(2));
          expect(sections.first.clubSectionId, 10);
          expect(sections.first.sectionName, 'Sección A');
          expect(sections.first.compositeScorePct, 80.0);
          expect(sections.first.rankPosition, 1);
          expect(sections.first.activeEnrollmentCount, 12);
        },
      );
    });

    test('returns Left(AuthFailure) when datasource throws AuthException',
        () async {
      dataSource.getSectionRankingsResult = AuthException(
        message: 'MEMBER_RANKING_SCOPE_DENIED',
        code: 403,
      );

      final result = await repository.getSectionRankings(yearId: 5);

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.code, 403);
        },
        (_) => fail('Expected Left'),
      );
    });

    test('returns Left(NetworkFailure) when offline', () async {
      final offlineRepo = SectionRankingsRepositoryImpl(
        remoteDataSource: dataSource,
        networkInfo: _NeverConnected(),
      );

      final result = await offlineRepo.getSectionRankings(yearId: 5);

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<NetworkFailure>()),
        (_) => fail('Expected Left'),
      );
    });
  });

  // ── getSectionMembers ─────────────────────────────────────────────────────────

  group('SectionRankingsRepositoryImpl.getSectionMembers', () {
    test('returns Right(List<SectionMember>) on 200 OK', () async {
      dataSource.getSectionMembersResult = [
        _memberDto(),
        _memberDto(
          enrollmentId: 2,
          userId: 'user-abc',
          memberName: 'Pedro Ramirez',
          compositeScorePct: 85.0,
          rankPosition: 2,
        ),
      ];

      final result = await repository.getSectionMembers(10, 5);

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected Right'),
        (members) {
          expect(members, hasLength(2));
          final first = members.first;
          expect(first.enrollmentId, 1);
          expect(first.memberName, 'Maria Lopez');
          expect(first.compositeScorePct, 90.0);
          expect(first.rankPosition, 1);
        },
      );
    });

    test('returns Left(ServerFailure) when datasource throws ServerException',
        () async {
      dataSource.getSectionMembersResult = ServerException(
        message: 'Not Found',
        code: 404,
      );

      final result = await repository.getSectionMembers(10, 5);

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<ServerFailure>());
          expect(failure.code, 404);
        },
        (_) => fail('Expected Left'),
      );
    });

    test('maps SectionMember entity fields from DTO correctly', () async {
      dataSource.getSectionMembersResult = [
        _memberDto(
          enrollmentId: 99,
          userId: 'user-999',
          memberName: 'Ana Torres',
          compositeScorePct: 77.3,
          rankPosition: 5,
        ),
      ];

      final result = await repository.getSectionMembers(10, 5);

      result.fold(
        (_) => fail('Expected Right'),
        (members) {
          final m = members.first;
          expect(m.enrollmentId, 99);
          expect(m.userId, 'user-999');
          expect(m.memberName, 'Ana Torres');
          expect(m.compositeScorePct, 77.3);
          expect(m.rankPosition, 5);
        },
      );
    });
  });
}
