import 'package:flutter_test/flutter_test.dart';

import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/network/network_info.dart';
import 'package:sacdia_app/features/rankings/data/datasources/rankings_remote_data_source.dart';
import 'package:sacdia_app/features/rankings/data/models/member_ranking_dto.dart';
import 'package:sacdia_app/features/rankings/data/models/section_ranking_dto.dart';
import 'package:sacdia_app/features/rankings/data/repositories/member_rankings_repository_impl.dart';
import 'package:sacdia_app/features/rankings/domain/entities/member_ranking.dart';

// ── Stubs ─────────────────────────────────────────────────────────────────────

class _StubDataSource implements RankingsRemoteDataSource {
  /// Set before each test case — [MyRankingResponseDto], [Exception], or
  /// [MemberRankingHiddenException].
  Object? getMyRankingResult;

  @override
  Future<MyRankingResponseDto> getMyRanking(
    int yearId, {
    cancelToken,
  }) async {
    final r = getMyRankingResult;
    if (r is Exception) throw r;
    return r as MyRankingResponseDto;
  }

  @override
  Future<List<SectionRankingDto>> getSectionRankings({
    required int yearId,
    int? clubId,
    int page = 1,
    int limit = 20,
    cancelToken,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<SectionMemberDto>> getSectionMembers(
    int sectionId,
    int yearId, {
    cancelToken,
  }) =>
      throw UnimplementedError();
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

MyRankingResponseDto _myRankingDto({
  String visibilityMode = 'self_only',
  bool includeMember = true,
}) {
  return MyRankingResponseDto(
    member: includeMember
        ? const MemberRankingDto(
            enrollmentId: 42,
            userId: 'user-abc',
            memberName: 'Juan Perez',
            compositeScorePct: 75.5,
            rankPosition: 3,
          )
        : null,
    visibilityMode: visibilityMode,
    topN: visibilityMode == 'self_and_top_n'
        ? [
            const AnonymizedTopNEntryDto(
              memberName: 'Miembro #1',
              compositeScorePct: 95.0,
              rankPosition: 1,
            ),
          ]
        : null,
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late _StubDataSource dataSource;
  late MemberRankingsRepositoryImpl repository;

  setUp(() {
    dataSource = _StubDataSource();
    repository = MemberRankingsRepositoryImpl(
      remoteDataSource: dataSource,
      networkInfo: _AlwaysConnected(),
    );
  });

  group('MemberRankingsRepositoryImpl.getMyRanking', () {
    // ── Case 1: 200 OK ────────────────────────────────────────────────────────

    test('returns Right(MyRankingView) on success', () async {
      dataSource.getMyRankingResult = _myRankingDto();

      final result = await repository.getMyRanking(5);

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected Right'),
        (view) {
          expect(view, isNotNull);
          expect(view!.member?.enrollmentId, 42);
          expect(view.member?.memberName, 'Juan Perez');
          expect(view.member?.compositeScorePct, 75.5);
          expect(view.member?.rankPosition, 3);
          expect(view.visibilityMode, MyRankingVisibilityMode.selfOnly);
        },
      );
    });

    // ── Case 2: 200 OK with top_n ─────────────────────────────────────────────

    test('maps top_n entries correctly when visibility=self_and_top_n',
        () async {
      dataSource.getMyRankingResult =
          _myRankingDto(visibilityMode: 'self_and_top_n');

      final result = await repository.getMyRanking(5);

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected Right'),
        (view) {
          expect(view!.visibilityMode,
              MyRankingVisibilityMode.selfAndTopN);
          expect(view.topN, isNotNull);
          expect(view.topN!, hasLength(1));
          expect(view.topN!.first.memberName, 'Miembro #1');
          expect(view.topN!.first.compositeScorePct, 95.0);
          expect(view.topN!.first.rankPosition, 1);
        },
      );
    });

    // ── Case 3: 403 MEMBER_RANKING_HIDDEN → Right(null) ───────────────────────

    test(
        'returns Right(null) when datasource throws MemberRankingHiddenException',
        () async {
      dataSource.getMyRankingResult = MemberRankingHiddenException();

      final result = await repository.getMyRanking(5);

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected Right(null)'),
        (view) => expect(view, isNull),
      );
    });

    // ── Case 4: Other 403 (MEMBER_RANKING_SCOPE_DENIED) → Left(AuthFailure) ──

    test('returns Left(AuthFailure) when datasource throws AuthException',
        () async {
      dataSource.getMyRankingResult = AuthException(
        message: 'MEMBER_RANKING_SCOPE_DENIED',
        code: 403,
      );

      final result = await repository.getMyRanking(5);

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.code, 403);
        },
        (_) => fail('Expected Left'),
      );
    });

    // ── Case 5: 500 → Left(ServerFailure) ────────────────────────────────────

    test('returns Left(ServerFailure) when datasource throws ServerException',
        () async {
      dataSource.getMyRankingResult =
          ServerException(message: 'Internal Server Error', code: 500);

      final result = await repository.getMyRanking(5);

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<ServerFailure>());
          expect((failure as ServerFailure).message, 'Internal Server Error');
          expect(failure.code, 500);
        },
        (_) => fail('Expected Left'),
      );
    });

    // ── Case 6: No internet → Left(NetworkFailure) ────────────────────────────

    test('returns Left(NetworkFailure) when device is offline', () async {
      final offlineRepo = MemberRankingsRepositoryImpl(
        remoteDataSource: dataSource,
        networkInfo: _NeverConnected(),
      );

      final result = await offlineRepo.getMyRanking(5);

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<NetworkFailure>()),
        (_) => fail('Expected Left'),
      );
    });
  });
}
