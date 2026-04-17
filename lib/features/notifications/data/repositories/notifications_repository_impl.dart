import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/notification_item.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../datasources/notifications_remote_data_source.dart';

/// Implementación del repositorio de notificaciones.
class NotificationsRepositoryImpl implements NotificationsRepository {
  final NotificationsRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  NotificationsRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  Left<Failure, T> _serverFailure<T>(ServerException e) =>
      Left(ServerFailure(message: e.message, code: e.code));

  Left<Failure, T> _authFailure<T>(AuthException e) =>
      Left(AuthFailure(message: e.message, code: e.code));

  Left<Failure, T> _unexpectedFailure<T>(Object e) =>
      Left(UnexpectedFailure(message: e.toString()));

  Left<Failure, T> _notFoundFailure<T>(NotFoundException e) =>
      Left(NotFoundFailure(message: e.message, code: e.code));

  @override
  Future<
          Either<Failure,
              ({List<NotificationItem> items, int total, int totalPages})>>
      getHistory({
    int page = 1,
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    try {
      final result = await remoteDataSource.getHistory(
        page: page,
        limit: limit,
        cancelToken: cancelToken,
      );
      final entities = result.items.map((m) => m.toEntity()).toList();
      return Right((
        items: entities,
        total: result.total,
        totalPages: result.totalPages,
      ));
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, int>> getUnreadCount() async {
    try {
      final count = await remoteDataSource.getUnreadCount();
      return Right(count);
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, void>> markAsRead(String deliveryId) async {
    try {
      await remoteDataSource.markAsRead(deliveryId);
      return const Right(null);
    } on NotFoundException catch (e) {
      return _notFoundFailure(e);
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, int>> markAllAsRead() async {
    try {
      final updated = await remoteDataSource.markAllAsRead();
      return Right(updated);
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }
}
