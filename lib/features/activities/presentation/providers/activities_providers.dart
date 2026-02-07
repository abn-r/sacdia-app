import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/activities_remote_data_source.dart';
import '../../data/repositories/activities_repository_impl.dart';
import '../../domain/entities/activity.dart';
import '../../domain/entities/attendance.dart';
import '../../domain/repositories/activities_repository.dart';
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

/// Provider para el caso de uso de registrar asistencia
final registerAttendanceProvider = Provider<RegisterAttendance>((ref) {
  return RegisterAttendance(ref.read(activitiesRepositoryProvider));
});

/// Provider para las actividades de un club
final clubActivitiesProvider =
    FutureProvider.autoDispose.family<List<Activity>, int>((ref, clubId) async {
  final getClubActivities = ref.read(getClubActivitiesProvider);
  final result = await getClubActivities(GetClubActivitiesParams(clubId: clubId));

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

/// State notifier para manejar el registro de asistencia
class AttendanceNotifier extends StateNotifier<AsyncValue<Attendance?>> {
  final RegisterAttendance registerAttendance;

  AttendanceNotifier(this.registerAttendance) : super(const AsyncValue.data(null));

  /// Registrar asistencia
  Future<void> register(int activityId, String userId, bool attended) async {
    state = const AsyncValue.loading();

    final result = await registerAttendance(
      RegisterAttendanceParams(
        activityId: activityId,
        userId: userId,
        attended: attended,
      ),
    );

    state = result.fold(
      (failure) => AsyncValue.error(failure.message, StackTrace.current),
      (attendance) => AsyncValue.data(attendance),
    );
  }
}

/// Provider para el notifier de asistencia
final attendanceNotifierProvider =
    StateNotifierProvider<AttendanceNotifier, AsyncValue<Attendance?>>((ref) {
  return AttendanceNotifier(ref.read(registerAttendanceProvider));
});
