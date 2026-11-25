import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart'
    show apiBaseUrlProvider;
import '../../../../providers/dio_provider.dart';
import '../../data/datasources/supervision_operations_remote_data_source.dart';
import '../../data/repositories/supervision_operations_repository_impl.dart';
import '../../domain/entities/supervision_operations.dart';
import '../../domain/repositories/supervision_operations_repository.dart';
import 'supervision_providers.dart';

final supervisionOperationsRemoteDataSourceProvider =
    Provider<SupervisionOperationsRemoteDataSource>((ref) {
  return SupervisionOperationsRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

final supervisionOperationsRepositoryProvider =
    Provider<SupervisionOperationsRepository>((ref) {
  return SupervisionOperationsRepositoryImpl(
    remoteDataSource: ref.read(supervisionOperationsRemoteDataSourceProvider),
  );
});

/// Operations dashboard of one territory (all null ids = the actor's scope).
final supervisionOperationsProvider = FutureProvider.autoDispose
    .family<SupervisionOperationsDashboard, SupervisionOperationsQuery>(
        (ref, query) async {
  final repository = ref.read(supervisionOperationsRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final result = await repository.getDashboard(
    query,
    cancelToken: cancelToken,
  );
  return result.fold(
    (failure) => throw SupervisionLoadException.fromFailure(failure),
    (dashboard) => dashboard,
  );
});
