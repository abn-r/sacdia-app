import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../providers/dio_provider.dart';
import '../../../../providers/storage_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/dashboard_remote_data_source.dart';
import '../../data/models/dashboard_summary_model.dart';
import '../../data/repositories/dashboard_repository_impl.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../domain/usecases/get_dashboard_data.dart';

const Duration _dashboardSummaryTtl = Duration(seconds: 90);
final Set<String> _dashboardSummaryRefreshInFlightKeys = {};

String _dashboardSummaryCacheKey({
  required String userId,
  required String assignmentId,
}) {
  return '${AppConstants.dashboardSummaryCacheKeyPrefix}_$userId'
      '_assignment_$assignmentId';
}

DashboardSummary? _readCachedDashboardSummary({
  required LocalStorage storage,
  required String cacheKey,
}) {
  if (storage.isExpired(cacheKey, maxAge: _dashboardSummaryTtl)) {
    return null;
  }

  final raw = storage.getString(cacheKey);
  if (raw == null || raw.isEmpty) return null;

  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return DashboardSummaryModel.fromJson(decoded);
    }
    if (decoded is Map) {
      return DashboardSummaryModel.fromJson(Map<String, dynamic>.from(decoded));
    }
    return null;
  } catch (e) {
    unawaited(storage.remove(cacheKey));
    unawaited(storage.remove('${cacheKey}_cached_at'));
    return null;
  }
}

Future<void> _saveCachedDashboardSummary({
  required LocalStorage storage,
  required String cacheKey,
  required DashboardSummary summary,
}) async {
  final serializable = (summary is DashboardSummaryModel)
      ? summary.toJson()
      : DashboardSummaryModel(
          userName: summary.userName,
          userAvatar: summary.userAvatar,
          clubName: summary.clubName,
          clubType: summary.clubType,
          userRole: summary.userRole,
          currentClassName: summary.currentClassName,
          currentClassInvestitureStatus: summary.currentClassInvestitureStatus,
          currentClassId: summary.currentClassId,
          classProgress: summary.classProgress,
          honorsCompleted: summary.honorsCompleted,
          honorsInProgress: summary.honorsInProgress,
          upcomingActivities: summary.upcomingActivities,
        ).toJson();

  await storage.saveString(cacheKey, jsonEncode(serializable));
  await storage.setCachedAt(cacheKey);
}

/// Provider para la fuente de datos remota del dashboard
final dashboardRemoteDataSourceProvider =
    Provider<DashboardRemoteDataSource>((ref) {
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
  bool _isDisposed = false;

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
    ref.onDispose(() {
      _isDisposed = true;
    });

    return _fetchFromCacheOrApi(
      userId: userId,
      activeAssignmentId: activeAssignmentId,
      cancelToken: cancelToken,
    );
  }

  Future<DashboardSummary?> _fetchFromCacheOrApi({
    required String userId,
    required String activeAssignmentId,
    CancelToken? cancelToken,
  }) async {
    final storage = ref.read(localStorageProvider);
    final cacheKey = _dashboardSummaryCacheKey(
      userId: userId,
      assignmentId: activeAssignmentId,
    );

    final cached = _readCachedDashboardSummary(
      storage: storage,
      cacheKey: cacheKey,
    );
    if (cached != null) {
      _scheduleBackgroundRefresh(
        cacheKey: cacheKey,
        userId: userId,
        activeAssignmentId: activeAssignmentId,
      );
      return cached;
    }

    return _fetchAndCache(
      storage: storage,
      cacheKey: cacheKey,
      cancelToken: cancelToken,
    );
  }

  Future<DashboardSummary?> _fetchAndCache({
    required LocalStorage storage,
    required String cacheKey,
    CancelToken? cancelToken,
  }) async {
    final result = await ref.read(getDashboardSummaryProvider)(
      const NoParams(),
      cancelToken: cancelToken,
    );

    final summary = result.fold(
      (failure) => null,
      (dashboard) => dashboard,
    );
    if (summary != null) {
      await _saveCachedDashboardSummary(
        storage: storage,
        cacheKey: cacheKey,
        summary: summary,
      );
    }

    return summary;
  }

  Future<void> _refreshInBackground({
    required LocalStorage storage,
    required String cacheKey,
    required String userId,
    required String activeAssignmentId,
  }) async {
    if (_dashboardSummaryRefreshInFlightKeys.contains(cacheKey)) {
      return;
    }

    _dashboardSummaryRefreshInFlightKeys.add(cacheKey);
    try {
      final result = await ref.read(getDashboardSummaryProvider)(
        const NoParams(),
        cancelToken: CancelToken(),
      );
      final summary = result.fold((_) => null, (dashboard) => dashboard);
      if (summary == null) return;

      await _saveCachedDashboardSummary(
        storage: storage,
        cacheKey: cacheKey,
        summary: summary,
      );

      final (refreshedUserId, refreshedActiveAssignmentId) = await ref.read(
        authNotifierProvider.selectAsync(
          (user) => (user?.id, user?.authorization?.activeAssignmentId),
        ),
      );
      if (refreshedUserId != userId ||
          refreshedActiveAssignmentId != activeAssignmentId) {
        return;
      }
      if (_isDisposed) {
        return;
      }

      state = AsyncValue.data(summary);
    } catch (_) {
      // Ignore background refresh failures so valid cached data stays visible.
      // Next build/focused refresh can recover from transient API issues.
    } finally {
      _dashboardSummaryRefreshInFlightKeys.remove(cacheKey);
    }
  }

  void _scheduleBackgroundRefresh({
    required String cacheKey,
    required String userId,
    required String activeAssignmentId,
  }) {
    final storage = ref.read(localStorageProvider);
    unawaited(
      _refreshInBackground(
        storage: storage,
        cacheKey: cacheKey,
        userId: userId,
        activeAssignmentId: activeAssignmentId,
      ),
    );
  }

  /// Recargar los datos del dashboard
  Future<void> refresh() async {
    state = const AsyncValue.loading();

    final cancelToken = CancelToken();
    ref.onDispose(() => cancelToken.cancel());

    final (userId, activeAssignmentId) = await ref.read(
      authNotifierProvider.selectAsync(
        (user) => (user?.id, user?.authorization?.activeAssignmentId),
      ),
    );
    if (userId == null || activeAssignmentId == null) {
      state = const AsyncValue.data(null);
      return;
    }

    final storage = ref.read(localStorageProvider);
    final cacheKey = _dashboardSummaryCacheKey(
      userId: userId,
      assignmentId: activeAssignmentId,
    );

    final result = await ref.read(getDashboardSummaryProvider)(
      const NoParams(),
      cancelToken: cancelToken,
    );

    final summary = result.fold((_) => null, (dashboard) => dashboard);
    if (summary == null) {
      state = result.fold(
        (failure) => AsyncValue.error(failure.message, StackTrace.current),
        (_) => const AsyncValue.data(null),
      );
      return;
    }

    await _saveCachedDashboardSummary(
      storage: storage,
      cacheKey: cacheKey,
      summary: summary,
    );
    state = AsyncValue.data(summary);
  }
}

/// Provider para el notifier del dashboard
final dashboardNotifierProvider =
    AsyncNotifierProvider<DashboardNotifier, DashboardSummary?>(() {
  return DashboardNotifier();
});
