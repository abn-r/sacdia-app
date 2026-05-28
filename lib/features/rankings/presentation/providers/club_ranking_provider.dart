import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/rankings_remote_data_source.dart';
import '../../data/repositories/club_rankings_repository_impl.dart';
import '../../domain/entities/club_ranking.dart';
import '../../domain/repositories/club_rankings_repository.dart';

typedef ClubRankingsParams = ({
  int clubTypeId,
  int yearId,
  int? localFieldId,
});

final clubRankingsRepositoryProvider = Provider<ClubRankingsRepository>((ref) {
  return ClubRankingsRepositoryImpl(
    remoteDataSource: ref.read(rankingsRemoteDataSourceProvider),
    networkInfo: ref.read(networkInfoProvider),
  );
});

final clubRankingsProvider = FutureProvider.autoDispose
    .family<List<ClubRanking>, ClubRankingsParams>((ref, params) async {
  ref.keepAlive();
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());

  final repo = ref.watch(clubRankingsRepositoryProvider);
  final result = await repo.getClubRankings(
    clubTypeId: params.clubTypeId,
    yearId: params.yearId,
    localFieldId: params.localFieldId,
    cancelToken: cancelToken,
  );

  return result.fold(
    (failure) => throw failure,
    (rankings) => rankings,
  );
});
