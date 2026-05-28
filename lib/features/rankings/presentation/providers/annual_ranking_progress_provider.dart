import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/annual_ranking_progress_remote_data_source.dart';
import '../../data/repositories/annual_ranking_progress_repository_impl.dart';
import '../../domain/entities/annual_ranking_progress.dart';
import '../../domain/repositories/annual_ranking_progress_repository.dart';

typedef AnnualRankingProgressParams = ({
  int sectionId,
  int yearId,
});

final annualRankingProgressRepositoryProvider =
    Provider<AnnualRankingProgressRepository>((ref) {
  return AnnualRankingProgressRepositoryImpl(
    remoteDataSource: ref.read(annualRankingProgressRemoteDataSourceProvider),
    networkInfo: ref.read(networkInfoProvider),
  );
});

final annualRankingProgressProvider = FutureProvider.autoDispose
    .family<AnnualRankingProgress, AnnualRankingProgressParams>(
        (ref, params) async {
  ref.keepAlive();
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());

  final repository = ref.watch(annualRankingProgressRepositoryProvider);
  final result = await repository.getAnnualRankingProgress(
    sectionId: params.sectionId,
    yearId: params.yearId,
    cancelToken: cancelToken,
  );

  return result.fold(
    (failure) => throw failure,
    (progress) => progress,
  );
});
