import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../providers/dio_provider.dart';
import '../../data/datasources/annual_ranking_progress_remote_data_source.dart';
import '../../data/datasources/rankings_remote_data_source.dart';

final rankingsRemoteDataSourceProvider =
    Provider<RankingsRemoteDataSource>((ref) {
  return RankingsRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: AppConstants.apiBaseUrl,
  );
});

final annualRankingProgressRemoteDataSourceProvider =
    Provider<AnnualRankingProgressRemoteDataSource>((ref) {
  return AnnualRankingProgressRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: AppConstants.apiBaseUrl,
  );
});
