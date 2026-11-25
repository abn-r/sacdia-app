import 'package:dartz/dartz.dart' show Either;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/forbidden.dart';
import '../../../auth/presentation/providers/auth_providers.dart'
    show apiBaseUrlProvider;
import '../../../../providers/catalogs_provider.dart';
import '../../../../providers/dio_provider.dart';
import '../../../../shared/models/catalogs/ecclesiastical_year_model.dart';
import '../../data/datasources/supervision_annual_progress_remote_data_source.dart';
import '../../data/repositories/supervision_annual_progress_repository_impl.dart';
import '../../domain/entities/supervision_annual_progress.dart';
import '../../domain/repositories/supervision_annual_progress_repository.dart';
import 'supervision_providers.dart';

final supervisionAnnualProgressRemoteDataSourceProvider =
    Provider<SupervisionAnnualProgressRemoteDataSource>((ref) {
  return SupervisionAnnualProgressRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

final supervisionAnnualProgressRepositoryProvider =
    Provider<SupervisionAnnualProgressRepository>((ref) {
  return SupervisionAnnualProgressRepositoryImpl(
    remoteDataSource:
        ref.read(supervisionAnnualProgressRemoteDataSourceProvider),
  );
});

/// Runs [call] with a token cancelled on dispose; failures become
/// [SupervisionLoadException].
Future<T> _load<T>(
  Ref ref,
  Future<Either<Failure, T>> Function(CancelToken token) call,
) async {
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final result = await call(cancelToken);
  return result.fold(
    (failure) => throw SupervisionLoadException.fromFailure(failure),
    (value) => value,
  );
}

/// Unions of a division (the server limits them to the actor's territory).
final supervisionUnionsProvider = FutureProvider.autoDispose
    .family<List<SupervisionTerritoryOption>, int>((ref, divisionId) {
  final repository = ref.read(supervisionAnnualProgressRepositoryProvider);
  return _load(
    ref,
    (token) => repository.getUnions(divisionId, cancelToken: token),
  );
});

/// Local fields of a union.
final supervisionLocalFieldsProvider = FutureProvider.autoDispose
    .family<List<SupervisionTerritoryOption>, int>((ref, unionId) {
  final repository = ref.read(supervisionAnnualProgressRepositoryProvider);
  return _load(
    ref,
    (token) => repository.getLocalFields(unionId, cancelToken: token),
  );
});

final supervisionAnnualProgressProvider = FutureProvider.autoDispose
    .family<SupervisionAnnualProgress, SupervisionAnnualProgressQuery>(
        (ref, query) {
  final repository = ref.read(supervisionAnnualProgressRepositoryProvider);
  return _load(
    ref,
    (token) => repository.getAnnualProgress(query, cancelToken: token),
  );
});

/// Year the screen reports on: the current ecclesiastical year, else the
/// newest active one, else null.
final supervisionProgressYearProvider =
    FutureProvider.autoDispose<EcclesiasticalYearModel?>((ref) async {
  Object? currentError;
  try {
    final current = await ref.watch(currentEcclesiasticalYearProvider.future);
    if (current != null) return current;
  } catch (e) {
    currentError = e;
  }
  try {
    final years = await ref.watch(ecclesiasticalYearsProvider(true).future);
    final active = years.where((y) => y.active).toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    return active.isEmpty ? null : active.first;
  } catch (e) {
    // The screen shows its own localized error; the raw exception text never
    // reaches the user.
    throw SupervisionLoadException(
      '',
      isForbidden: isForbiddenFailure(currentError ?? e),
    );
  }
});
