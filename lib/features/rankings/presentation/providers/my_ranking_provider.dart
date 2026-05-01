import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/rankings_remote_data_source.dart';
import '../../data/repositories/member_rankings_repository_impl.dart';
import '../../domain/entities/member_ranking.dart';
import '../../domain/repositories/member_rankings_repository.dart';

// ── Infrastructure providers ──────────────────────────────────────────────────

/// Provider for the member rankings repository.
final memberRankingsRepositoryProvider =
    Provider<MemberRankingsRepository>((ref) {
  return MemberRankingsRepositoryImpl(
    remoteDataSource: ref.read(rankingsRemoteDataSourceProvider),
    networkInfo: ref.read(networkInfoProvider),
  );
});

// ── Data provider ─────────────────────────────────────────────────────────────

/// Fetches the calling member's own ranking for a given [yearId].
///
/// Returns:
/// - [AsyncValue.data(MyRankingView)] — ranking available
/// - [AsyncValue.data(null)] — visibility = hidden (empty state, NOT error)
/// - [AsyncValue.error(Failure)] — auth or network error
final myRankingProvider =
    FutureProvider.autoDispose.family<MyRankingView?, int>(
        (ref, yearId) async {
  ref.keepAlive();
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());

  final repo = ref.watch(memberRankingsRepositoryProvider);
  final result =
      await repo.getMyRanking(yearId, cancelToken: cancelToken);

  return result.fold(
    (failure) => throw failure,
    (data) => data, // null when hidden, MyRankingView when available
  );
});
