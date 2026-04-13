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

  /// Obtiene el número de entregas no leídas del usuario actual.
  ///
  /// GET /notifications/unread-count
  Future<Either<Failure, int>> getUnreadCount();

  /// Marca una entrega individual como leída.
  ///
  /// PATCH /notifications/:deliveryId/read
  Future<Either<Failure, void>> markAsRead(String deliveryId);

  /// Marca todas las entregas no leídas del usuario como leídas.
  ///
  /// PATCH /notifications/read-all
  /// Retorna el número de registros actualizados.
  Future<Either<Failure, int>> markAllAsRead();
}
