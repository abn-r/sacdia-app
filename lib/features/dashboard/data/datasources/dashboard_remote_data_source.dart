import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/dashboard_summary_model.dart';

/// Interfaz para la fuente de datos remota del dashboard
abstract class DashboardRemoteDataSource {
  /// Obtiene los datos del dashboard para un usuario
  Future<DashboardSummaryModel> getDashboardData(
    String userId, {
    Map<String, dynamic>? userMetadata,
  });
}

/// Implementación de la fuente de datos remota del dashboard
class DashboardRemoteDataSourceImpl implements DashboardRemoteDataSource {
  static const _tag = 'DashboardDS';

  const DashboardRemoteDataSourceImpl();

  @override
  Future<DashboardSummaryModel> getDashboardData(
    String userId, {
    Map<String, dynamic>? userMetadata,
  }) async {
    try {
      final userData = userMetadata ?? {};

      final firstName = (userData['name'] as String?) ?? '';
      final paternalLn = (userData['paternal_last_name'] as String?) ?? '';
      final maternalLn = (userData['maternal_last_name'] as String?) ?? '';
      final fullName = [firstName, paternalLn, maternalLn]
          .where((s) => s.isNotEmpty)
          .join(' ');

      final rawRoles = userData['roles'] as List<dynamic>?;
      final firstRole = rawRoles?.isNotEmpty == true
          ? rawRoles!.first as String?
          : null;

      final clubData = userData['club'] as Map<String, dynamic>?;

      final dashboardData = {
        'user_name': fullName.isNotEmpty ? fullName : 'Usuario',
        'user_avatar': userData['user_image'] as String?,
        'club_name': clubData?['club_name'] as String?,
        'club_type': clubData?['club_type'] as String?,
        'user_role': firstRole,
        'current_class_name': null,
        'class_progress': 0.0,
        'honors_completed': 0,
        'honors_in_progress': 0,
        'upcoming_activities': <Map<String, dynamic>>[],
      };

      return DashboardSummaryModel.fromJson(dashboardData);
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      AppLogger.e('Error inesperado en dashboard', tag: _tag, error: e);
      throw ServerException(message: e.toString());
    }
  }
}
