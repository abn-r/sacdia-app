import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../members/presentation/providers/members_providers.dart';
import '../../../../providers/dio_provider.dart';
import '../../data/datasources/activities_remote_data_source.dart';
import '../../data/models/club_section_model.dart';
import '../../data/models/create_activity_request.dart';
import '../../data/repositories/activities_repository_impl.dart';
import '../../domain/entities/activity.dart';
import '../../domain/repositories/activities_repository.dart';
import '../../domain/usecases/create_activity.dart';
import '../../domain/usecases/get_club_activities.dart';
import '../../domain/usecases/get_activity_detail.dart';
import '../../domain/usecases/register_attendance.dart';

/// Provider para el data source remoto de actividades
final activitiesRemoteDataSourceProvider = Provider<ActivitiesRemoteDataSource>((ref) {
  final dio = ref.read(dioProvider);
  final baseUrl = ref.read(apiBaseUrlProvider);

  return ActivitiesRemoteDataSourceImpl(
    dio: dio,
    baseUrl: baseUrl,
  );
});

/// Provider para el repositorio de actividades
final activitiesRepositoryProvider = Provider<ActivitiesRepository>((ref) {
  final remoteDataSource = ref.read(activitiesRemoteDataSourceProvider);
  final networkInfo = ref.read(networkInfoProvider);

  return ActivitiesRepositoryImpl(
    remoteDataSource: remoteDataSource,
    networkInfo: networkInfo,
  );
});

/// Provider para el caso de uso de obtener actividades del club
final getClubActivitiesProvider = Provider<GetClubActivities>((ref) {
  return GetClubActivities(ref.read(activitiesRepositoryProvider));
});

/// Provider para el caso de uso de obtener detalle de actividad
final getActivityDetailProvider = Provider<GetActivityDetail>((ref) {
  return GetActivityDetail(ref.read(activitiesRepositoryProvider));
});

/// Provider para el caso de uso de crear actividad
final createActivityUseCaseProvider = Provider<CreateActivity>((ref) {
  return CreateActivity(ref.read(activitiesRepositoryProvider));
});

/// Provider para el caso de uso de registrar asistencia
final registerAttendanceProvider = Provider<RegisterAttendance>((ref) {
  return RegisterAttendance(ref.read(activitiesRepositoryProvider));
});

// ─────────────────────────────────────────────────────────────────────────────
// CLUB ACTIVITIES - family key con soporte para filtros
// ─────────────────────────────────────────────────────────────────────────────

/// Parámetros de consulta para el provider de actividades del club.
/// Implementa == y hashCode para que Riverpod family funcione correctamente.
///
/// [activityTypeId] is intentionally excluded from the family key so that
/// filter chip taps do NOT trigger new network requests. Filtering by activity
/// type is applied locally after the full list is fetched once.
class ClubActivitiesParams {
  final int clubId;
  final int? clubTypeId;

  const ClubActivitiesParams({
    required this.clubId,
    this.clubTypeId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClubActivitiesParams &&
          other.clubId == clubId &&
          other.clubTypeId == clubTypeId;

  @override
  int get hashCode => Object.hash(clubId, clubTypeId);
}

/// Provider para las actividades de un club.
/// Fetches ALL activities for the club once and caches the result. Filter chips
/// apply locally inside ActivitiesListView using _selectedFilter state, so
/// tapping a chip never triggers an additional network request.
final clubActivitiesProvider =
    FutureProvider.autoDispose.family<List<Activity>, ClubActivitiesParams>(
        (ref, params) async {
  ref.keepAlive();
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final getClubActivities = ref.read(getClubActivitiesProvider);
  final result = await getClubActivities(
    GetClubActivitiesParams(
      clubId: params.clubId,
      clubTypeId: params.clubTypeId,
    ),
    cancelToken: cancelToken,
  );

  return result.fold(
    (failure) => throw Exception(failure.message),
    (activities) => activities,
  );
});


/// Provider para el detalle de una actividad.
/// Caches the result with a 5-minute timer: the instance is kept alive while
/// any listener is active and is auto-disposed 5 minutes after the last
/// listener is removed, preventing unbounded growth across many navigations.
final activityDetailProvider =
    FutureProvider.autoDispose.family<Activity, int>((ref, activityId) async {
  final link = ref.keepAlive();
  final cancelToken = CancelToken();
  Timer? timer;
  ref.onCancel(() {
    timer = Timer(const Duration(minutes: 5), () {
      link.close();
    });
  });
  ref.onResume(() {
    timer?.cancel();
  });
  ref.onDispose(() {
    timer?.cancel();
    cancelToken.cancel();
  });
  final getActivityDetail = ref.read(getActivityDetailProvider);
  final result = await getActivityDetail(
    GetActivityDetailParams(activityId: activityId),
    cancelToken: cancelToken,
  );

  return result.fold(
    (failure) => throw Exception(failure.message),
    (activity) => activity,
  );
});

/// Notifier para manejar el registro de asistencia
class AttendanceNotifier extends AutoDisposeAsyncNotifier<int?> {
  @override
  Future<int?> build() async => null;

  /// Registrar asistencia de múltiples usuarios
  Future<void> registerMultiple(int activityId, List<String> userIds) async {
    state = const AsyncValue.loading();

    final result = await ref.read(registerAttendanceProvider)(
      RegisterAttendanceParams(
        activityId: activityId,
        userIds: userIds,
      ),
    );

    state = result.fold(
      (failure) => AsyncValue.error(failure.message, StackTrace.current),
      (count) => AsyncValue.data(count),
    );
  }

  /// Registrar asistencia de un solo usuario (conveniencia)
  Future<void> register(int activityId, String userId) async {
    await registerMultiple(activityId, [userId]);
  }
}

/// Provider para el notifier de asistencia
final attendanceNotifierProvider =
    AsyncNotifierProvider.autoDispose<AttendanceNotifier, int?>(() {
  return AttendanceNotifier();
});

// ─────────────────────────────────────────────────────────────────────────────
// CREATE ACTIVITY
// ─────────────────────────────────────────────────────────────────────────────

/// Estado para la operación de creación de actividad
class CreateActivityState {
  final bool isLoading;
  final Activity? createdActivity;
  final String? errorMessage;

  const CreateActivityState({
    this.isLoading = false,
    this.createdActivity,
    this.errorMessage,
  });

  CreateActivityState copyWith({
    bool? isLoading,
    Activity? createdActivity,
    String? errorMessage,
  }) {
    return CreateActivityState(
      isLoading: isLoading ?? this.isLoading,
      createdActivity: createdActivity ?? this.createdActivity,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Notifier para manejar la creación de actividades
class CreateActivityNotifier extends AutoDisposeNotifier<CreateActivityState> {
  @override
  CreateActivityState build() => const CreateActivityState();

  /// Crea una nueva actividad y actualiza el estado
  Future<bool> create({
    required int clubId,
    required CreateActivityRequest request,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final result = await ref.read(createActivityUseCaseProvider)(
      CreateActivityParams(clubId: clubId, request: request),
    );

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
      (activity) {
        state = state.copyWith(isLoading: false, createdActivity: activity);
        return true;
      },
    );
  }

  /// Limpia el estado para reutilizar el notifier
  void reset() {
    state = const CreateActivityState();
  }
}

/// Provider para el notifier de creación de actividad
final createActivityNotifierProvider =
    NotifierProvider.autoDispose<CreateActivityNotifier, CreateActivityState>(
  CreateActivityNotifier.new,
);

// ─────────────────────────────────────────────────────────────────────────────
// DELETE ACTIVITY
// ─────────────────────────────────────────────────────────────────────────────

/// Notifier para manejar la eliminación de actividades
class DeleteActivityNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Elimina una actividad por su ID
  Future<bool> delete(int activityId) async {
    state = const AsyncValue.loading();

    final repository = ref.read(activitiesRepositoryProvider);
    final result = await repository.deleteActivity(activityId);

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        // Invalidar la lista de actividades para que se recargue
        ref.invalidate(clubActivitiesProvider);
        return true;
      },
    );
  }
}

/// Provider para el notifier de eliminación de actividad
final deleteActivityNotifierProvider =
    AsyncNotifierProvider.autoDispose<DeleteActivityNotifier, void>(
  DeleteActivityNotifier.new,
);

// ─────────────────────────────────────────────────────────────────────────────
// UPDATE ACTIVITY
// ─────────────────────────────────────────────────────────────────────────────

/// Estado para la operación de actualización de actividad
class UpdateActivityState {
  final bool isLoading;
  final Activity? updatedActivity;
  final String? errorMessage;

  const UpdateActivityState({
    this.isLoading = false,
    this.updatedActivity,
    this.errorMessage,
  });

  UpdateActivityState copyWith({
    bool? isLoading,
    Activity? updatedActivity,
    String? errorMessage,
  }) {
    return UpdateActivityState(
      isLoading: isLoading ?? this.isLoading,
      updatedActivity: updatedActivity ?? this.updatedActivity,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Notifier para manejar la actualización de actividades
class UpdateActivityNotifier
    extends AutoDisposeNotifier<UpdateActivityState> {
  @override
  UpdateActivityState build() => const UpdateActivityState();

  /// Actualiza una actividad existente
  Future<bool> update({
    required int activityId,
    String? name,
    String? description,
    double? lat,
    double? long,
    String? activityTime,
    String? activityDate,
    String? activityEndDate,
    String? activityPlace,
    int? platform,
    int? activityTypeId,
    String? linkMeet,
    bool? active,
    Set<String> clearFields = const {},
    List<int>? clubSectionIds,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final repository = ref.read(activitiesRepositoryProvider);
    final result = await repository.updateActivity(
      activityId: activityId,
      name: name,
      description: description,
      lat: lat,
      long: long,
      activityTime: activityTime,
      activityDate: activityDate,
      activityEndDate: activityEndDate,
      activityPlace: activityPlace,
      platform: platform,
      activityTypeId: activityTypeId,
      linkMeet: linkMeet,
      active: active,
      clearFields: clearFields,
      clubSectionIds: clubSectionIds,
    );

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
      (activity) {
        state = state.copyWith(isLoading: false, updatedActivity: activity);
        // Invalidar los providers para que se recarguen con datos frescos
        ref.invalidate(clubActivitiesProvider);
        ref.invalidate(activityDetailProvider(activityId));
        return true;
      },
    );
  }

  /// Limpia el estado para reutilizar el notifier
  void reset() {
    state = const UpdateActivityState();
  }
}

/// Provider para el notifier de actualización de actividad
final updateActivityNotifierProvider =
    NotifierProvider.autoDispose<UpdateActivityNotifier, UpdateActivityState>(
  UpdateActivityNotifier.new,
);

// ─────────────────────────────────────────────────────────────────────────────
// CLUB SECTIONS — para el picker de actividades conjuntas
// ─────────────────────────────────────────────────────────────────────────────

/// Carga las secciones del club activo para alimentar el picker de actividades
/// conjuntas. Solo usado cuando el usuario es director.
///
/// Retorna la lista de secciones (incluye la sección propia del director).
final clubSectionsForActivityProvider =
    FutureProvider.autoDispose<List<ClubSectionModel>>((ref) async {
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());

  final ctx = await ref.watch(clubContextProvider.future);
  if (ctx == null) return const [];

  final dataSource = ref.read(activitiesRemoteDataSourceProvider);
  return dataSource.getClubSections(ctx.clubId, cancelToken: cancelToken);
});
