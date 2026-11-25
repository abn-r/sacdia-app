import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/forbidden.dart';
import '../../../auth/presentation/providers/auth_providers.dart'
    show apiBaseUrlProvider;
import '../../../../providers/dio_provider.dart';
import '../../data/datasources/supervision_remote_data_source.dart';
import '../../data/repositories/supervision_repository_impl.dart';
import '../../domain/entities/supervision_pending_counts.dart';
import '../../domain/repositories/supervision_repository.dart';

/// Error raised by the supervision read providers; [isForbidden] lets
/// `isForbiddenFailure` classify a 403 without sniffing the message.
class SupervisionLoadException implements Exception, ForbiddenAware {
  const SupervisionLoadException(this.message, {this.isForbidden = false});

  factory SupervisionLoadException.fromFailure(Failure failure) =>
      SupervisionLoadException(
        failure.message,
        isForbidden: isForbiddenFailure(failure),
      );

  final String message;

  @override
  final bool isForbidden;

  @override
  String toString() => 'Exception: $message';
}

final supervisionRemoteDataSourceProvider =
    Provider<SupervisionRemoteDataSource>((ref) {
  return SupervisionRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

final supervisionRepositoryProvider = Provider<SupervisionRepository>((ref) {
  return SupervisionRepositoryImpl(
    remoteDataSource: ref.read(supervisionRemoteDataSourceProvider),
  );
});

/// Pending counts for the supervision hub (null count = no such function).
final supervisionPendingCountsProvider =
    FutureProvider.autoDispose<SupervisionPendingCounts>((ref) async {
  final repository = ref.read(supervisionRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final result = await repository.getPendingCounts(cancelToken: cancelToken);
  return result.fold(
    (failure) => throw SupervisionLoadException.fromFailure(failure),
    (counts) => counts,
  );
});
