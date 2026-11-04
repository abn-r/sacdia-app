import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../providers/dio_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/dashboard_pending_remote_data_source.dart';
import '../../data/repositories/dashboard_pending_repository_impl.dart';
import '../../domain/entities/dashboard_pending.dart';
import '../../domain/repositories/dashboard_pending_repository.dart';

final dashboardPendingRemoteDataSourceProvider =
    Provider<DashboardPendingRemoteDataSource>((ref) {
  return DashboardPendingRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

final dashboardPendingRepositoryProvider =
    Provider<DashboardPendingRepository>((ref) {
  return DashboardPendingRepositoryImpl(
    remoteDataSource: ref.read(dashboardPendingRemoteDataSourceProvider),
  );
});

/// Pendientes de gestión de la sección activa (`GET /dashboard/pending`).
///
/// `autoDispose` y sin estado de perfil que registrar: solo vive mientras la
/// tarjeta de «Pendientes» está en pantalla (modo gestión). Depende de
/// `userId` + `activeAssignmentId` igual que `dashboardNotifierProvider`, así
/// que un cambio de sección o de perfil lo recalcula, y no pide nada mientras
/// la asignación activa es desconocida. El pull-to-refresh del inicio lo
/// invalida.
///
/// Es auxiliar: si el endpoint falla (404, red, 5xx) devuelve `null`, se
/// registra en el logger y la tarjeta simplemente no se muestra.
final dashboardPendingProvider =
    FutureProvider.autoDispose<DashboardPending?>((ref) async {
  final (userId, activeAssignmentId) = await ref.watch(
    authNotifierProvider.selectAsync(
      (user) => (user?.id, user?.authorization?.activeAssignmentId),
    ),
  );
  if (userId == null || activeAssignmentId == null) return null;

  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);

  final result = await ref
      .read(dashboardPendingRepositoryProvider)
      .getPending(cancelToken: cancelToken);

  return result.fold(
    (failure) {
      AppLogger.w(
        'Pendientes del inicio no disponibles: ${failure.message}',
        tag: 'DashboardPending',
      );
      return null;
    },
    (pending) => pending,
  );
});
