import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/dashboard_remote_data_source.dart';
import '../../data/repositories/dashboard_repository_impl.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../domain/usecases/get_dashboard_data.dart';

/// Provider para la fuente de datos remota del dashboard
final dashboardRemoteDataSourceProvider = Provider<DashboardRemoteDataSource>((ref) {
  return const DashboardRemoteDataSourceImpl();
});

/// Provider para el repositorio del dashboard
final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final networkInfo = ref.read(networkInfoProvider);
  final remoteDataSource = ref.read(dashboardRemoteDataSourceProvider);

  return DashboardRepositoryImpl(
    remoteDataSource: remoteDataSource,
    networkInfo: networkInfo,
  );
});

/// Provider para el caso de uso de obtener datos del dashboard
final getDashboardDataProvider = Provider<GetDashboardData>((ref) {
  return GetDashboardData(ref.read(dashboardRepositoryProvider));
});

/// Notifier para manejar los datos del dashboard
class DashboardNotifier extends AsyncNotifier<DashboardSummary?> {
  @override
  Future<DashboardSummary?> build() async {
    // Obtener el usuario actual
    final user = await ref.watch(authNotifierProvider.future);

    if (user == null) {
      return null;
    }

    // Obtener los datos del dashboard
    final result = await ref.read(getDashboardDataProvider)(
      GetDashboardDataParams(userId: user.id, userMetadata: user.metadata),
    );

    return result.fold(
      (failure) => null,
      (dashboard) => dashboard,
    );
  }

  /// Recargar los datos del dashboard
  Future<void> refresh() async {
    state = const AsyncValue.loading();

    final user = await ref.read(authNotifierProvider.future);

    if (user == null) {
      state = AsyncValue.error(
        'No hay usuario autenticado',
        StackTrace.current,
      );
      return;
    }

    final result = await ref.read(getDashboardDataProvider)(
      GetDashboardDataParams(userId: user.id, userMetadata: user.metadata),
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
