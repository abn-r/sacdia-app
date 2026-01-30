import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/dashboard_entity.dart';

/// Interfaz del repositorio para la pantalla de inicio
abstract class HomeRepository {
  /// Obtiene los datos del dashboard
  Future<Either<Failure, DashboardEntity>> getDashboardData();
  
  /// Marca las notificaciones como leídas
  Future<Either<Failure, bool>> markNotificationsAsRead();
  
  /// Obtiene información de perfil del usuario
  Future<Either<Failure, Map<String, dynamic>>> getUserProfile();
}
