import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../providers/dio_provider.dart';
import '../../data/datasources/activities_remote_data_source.dart';
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
class ClubActivitiesParams {
  final int clubId;
  final int? clubTypeId;
  final int? activityTypeId;

  const ClubActivitiesParams({
    required this.clubId,
    this.clubTypeId,
    this.activityTypeId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClubActivitiesParams &&
          other.clubId == clubId &&
          other.clubTypeId == clubTypeId &&
          other.activityTypeId == activityTypeId;

  @override
  int get hashCode => Object.hash(clubId, clubTypeId, activityTypeId);
}

/// Provider para las actividades de un club con filtros opcionales
final clubActivitiesProvider =
    FutureProvider.autoDispose.family<List<Activity>, ClubActivitiesParams>(
        (ref, params) async {
  final getClubActivities = ref.read(getClubActivitiesProvider);
  final result = await getClubActivities(
    GetClubActivitiesParams(
      clubId: params.clubId,
      clubTypeId: params.clubTypeId,
      activityTypeId: params.activityTypeId,
    ),
  );

  return result.fold(
    (failure) => throw Exception(failure.message),
    (activities) => activities,
  );
});


/// Provider para el detalle de una actividad
final activityDetailProvider =
    FutureProvider.autoDispose.family<Activity, int>((ref, activityId) async {
  final getActivityDetail = ref.read(getActivityDetailProvider);
  final result = await getActivityDetail(GetActivityDetailParams(activityId: activityId));

  return result.fold(
    (failure) => throw Exception(failure.message),
    (activity) => activity,
  );
});

/// Notifier para manejar el registro de asistencia
class AttendanceNotifier extends AsyncNotifier<int?> {
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
    AsyncNotifierProvider<AttendanceNotifier, int?>(() {
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
class CreateActivityNotifier extends StateNotifier<CreateActivityState> {
  final CreateActivity _createActivity;

  CreateActivityNotifier(this._createActivity)
      : super(const CreateActivityState());

  /// Crea una nueva actividad y actualiza el estado
  Future<bool> create({
    required int clubId,
    required CreateActivityRequest request,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final result = await _createActivity(
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
    StateNotifierProvider.autoDispose<CreateActivityNotifier, CreateActivityState>(
  (ref) {
    final useCase = ref.read(createActivityUseCaseProvider);
    return CreateActivityNotifier(useCase);
  },
);
