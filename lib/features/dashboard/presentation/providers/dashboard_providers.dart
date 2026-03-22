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
    final userId = await ref.watch(
      authNotifierProvider.selectAsync((user) => user?.id),
    );
    if (userId == null) return null;

    return _fetch();
  }

  Future<DashboardSummary?> _fetch() async {
    final result = await ref.read(getDashboardSummaryProvider)(const NoParams());
    return result.fold(
      (failure) => null,
      (dashboard) => dashboard,
    );
  }

  /// Recargar los datos del dashboard
  Future<void> refresh() async {
    state = const AsyncValue.loading();

    final result = await ref.read(getDashboardSummaryProvider)(const NoParams());

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
