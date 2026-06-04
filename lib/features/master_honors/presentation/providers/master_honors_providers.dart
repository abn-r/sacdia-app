import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/dio_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/master_honors_remote_data_source.dart';
import '../../data/repositories/master_honors_repository_impl.dart';
import '../../domain/entities/user_master_honor.dart';
import '../../domain/repositories/master_honors_repository.dart';

final masterHonorsRemoteDataSourceProvider =
    Provider<MasterHonorsRemoteDataSource>((ref) {
  final dio = ref.read(dioProvider);
  final baseUrl = ref.read(apiBaseUrlProvider);

  return MasterHonorsRemoteDataSourceImpl(
    dio: dio,
    baseUrl: baseUrl,
  );
});

final masterHonorsRepositoryProvider = Provider<MasterHonorsRepository>((ref) {
  return MasterHonorsRepositoryImpl(
    remoteDataSource: ref.read(masterHonorsRemoteDataSourceProvider),
    networkInfo: ref.read(networkInfoProvider),
  );
});

final userMasterHonorsProvider =
    FutureProvider.autoDispose<List<UserMasterHonor>>((ref) async {
  ref.keepAlive();
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());

  final userId = await ref.watch(
    authNotifierProvider.selectAsync((user) => user?.id),
  );

  if (userId == null) {
    throw Exception(tr('errors.user_not_authenticated'));
  }

  final repository = ref.read(masterHonorsRepositoryProvider);
  final result = await repository.getUserMasterHonors(
    userId,
    cancelToken: cancelToken,
  );

  return result.fold(
    (failure) => throw Exception(failure.message),
    (masterHonors) => masterHonors,
  );
});

/// Hook estable para que notificaciones `master_honor_changed` invaliden cache.
final masterHonorsInvalidationProvider = Provider<void Function()>((ref) {
  return () => ref.invalidate(userMasterHonorsProvider);
});
