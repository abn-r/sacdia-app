import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../providers/dio_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/dashboard_remote_data_source.dart';
import '../../data/repositories/dashboard_repository_impl.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../domain/usecases/get_dashboard_data.dart';

/// Provider para la fuente de datos remota del dashboard
final dashboardRemoteDataSourceProvider = Provider<DashboardRemoteDataSource>((ref) {
  return DashboardRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

/// Provider para el repositorio del dashboard
final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepositoryImpl(
    remoteDataSource: ref.read(dashboardRemoteDataSourceProvider),
    networkInfo: ref.read(networkInfoProvider),
  );
});

/// Provider para el caso de uso de obtener el resumen del dashboard
final getDashboardSummaryProvider = Provider<GetDashboardSummary>((ref) {
  return GetDashboardSummary(ref.read(dashboardRepositoryProvider));
});

/// Notifier para manejar los datos del dashboard
class DashboardNotifier extends AsyncNotifier<DashboardSummary?> {
  @override
  Future<DashboardSummary?> build() async {
    // Reaccionar a cambios en la sesión: si el usuario se desloguea, limpiar.
    // También reaccionar a cambios en el contexto activo (club switch) para
    // que el dashboard se refresque con los datos del nuevo club.
    final (userId, activeAssignmentId) = await ref.watch(
      authNotifierProvider.selectAsync(
        (user) => (user?.id, user?.authorization?.activeAssignmentId),
      ),
    );
    if (userId == null) return null;

    // Do NOT fetch the dashboard while the active assignment is unknown.
    // When the datasource runs auto-activation (PATCH /auth/me/context), the
    // auth state briefly has a valid userId but a null activeAssignmentId.
    // Fetching at that moment hits /dashboard/summary before the server context
    // has been updated, returning stale data from the previous session. We wait
    // until the auto-activation completes and the auth state emits a non-null
    // activeAssignmentId before making the dashboard request.
    if (activeAssignmentId == null) return null;

    final cancelToken = CancelToken();
    ref.onDispose(() => cancelToken.cancel());

    return _fetch(cancelToken: cancelToken);
  }

  Future<DashboardSummary?> _fetch({CancelToken? cancelToken}) async {
    final result = await ref.read(getDashboardSummaryProvider)(
      const NoParams(),
      cancelToken: cancelToken,
    );
    return result.fold(
      (failure) => null,
      (dashboard) => dashboard,
    );
  }

  /// Recargar los datos del dashboard
  Future<void> refresh() async {
    state = const AsyncValue.loading();

    final cancelToken = CancelToken();
    ref.onDispose(() => cancelToken.cancel());

    final result = await ref.read(getDashboardSummaryProvider)(
      const NoParams(),
      cancelToken: cancelToken,
    );

    state = result.fold(
      (failure) => AsyncValue.error(failure.message, StackTrace.current),
      (dashboard) => AsyncValue.data(dashboard),
    );
  }
}

/// Provider para el notifier del dashboard
final dashboardNotifierProvider = AsyncNotifierProvider<DashboardNotifier, DashboardSummary?>(() {
  return DashboardNotifier();
});
