import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/failures.dart';
import '../entities/notification_item.dart';

/// Interfaz del repositorio de notificaciones (dominio).
abstract class NotificationsRepository {
  /// Obtiene el historial paginado de notificaciones enviadas.
  ///
  /// GET /notifications/history?page=N&limit=N
  Future<Either<Failure, ({List<NotificationItem> items, int total, int totalPages})>> getHistory({
    int page = 1,
    int limit = 20,
    CancelToken? cancelToken,
  });
}
