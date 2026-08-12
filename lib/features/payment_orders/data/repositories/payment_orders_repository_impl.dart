import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/cancel_token_adapter.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../../domain/entities/payment_order.dart';
import '../../domain/repositories/payment_orders_repository.dart';
import '../datasources/payment_orders_remote_data_source.dart';

/// Implementación del repositorio de órdenes de pago territoriales.
class PaymentOrdersRepositoryImpl implements PaymentOrdersRepository {
  final PaymentOrdersRemoteDataSource remoteDataSource;

  PaymentOrdersRepositoryImpl({required this.remoteDataSource});

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() body) async {
    try {
      return Right(await body());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, PaymentOrdersContext>> getContext({
    RequestCancelToken? cancelToken,
  }) {
    return _guard(() async {
      final model = await remoteDataSource.getContext(
        cancelToken: cancelToken.asDioCancelToken(),
      );
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, PaymentOrder>> createInsuranceOrder({
    required int cycleConfigId,
    required List<String> beneficiaryUserIds,
  }) {
    return _guard(() async {
      final model = await remoteDataSource.createInsuranceOrder(
        cycleConfigId: cycleConfigId,
        beneficiaryUserIds: beneficiaryUserIds,
      );
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, PaymentOrder>> createCamporeeOrder({
    required int camporeeId,
    required List<String> beneficiaryUserIds,
  }) {
    return _guard(() async {
      final model = await remoteDataSource.createCamporeeOrder(
        camporeeId: camporeeId,
        beneficiaryUserIds: beneficiaryUserIds,
      );
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, List<PaymentOrder>>> listOrders({
    PaymentOrderPurpose? purpose,
    PaymentOrderStatus? status,
    int? camporeeId,
    RequestCancelToken? cancelToken,
  }) {
    return _guard(() async {
      final models = await remoteDataSource.listOrders(
        purpose: purpose?.apiValue,
        status: status?.apiValue,
        camporeeId: camporeeId,
        cancelToken: cancelToken.asDioCancelToken(),
      );
      return models.map((m) => m.toEntity()).toList();
    });
  }

  @override
  Future<Either<Failure, PaymentOrder>> getOrder(
    String orderId, {
    RequestCancelToken? cancelToken,
  }) {
    return _guard(() async {
      final model = await remoteDataSource.getOrder(
        orderId,
        cancelToken: cancelToken.asDioCancelToken(),
      );
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, String>> downloadOrderPdf(
    String orderId, {
    RequestCancelToken? cancelToken,
  }) {
    return _guard(() {
      return remoteDataSource.downloadOrderPdf(
        orderId,
        cancelToken: cancelToken.asDioCancelToken(),
      );
    });
  }

  @override
  Future<Either<Failure, PaymentOrder>> uploadProof({
    required String orderId,
    required String filePath,
    required String fileName,
    required String mimeType,
  }) {
    return _guard(() async {
      final model = await remoteDataSource.uploadProof(
        orderId: orderId,
        filePath: filePath,
        fileName: fileName,
        mimeType: mimeType,
      );
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, PaymentOrder>> cancelOrder(String orderId) {
    return _guard(() async {
      final model = await remoteDataSource.cancelOrder(orderId);
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, InsuranceReassignment>> createReassignment({
    required int insuranceAssignmentId,
    required String toUserId,
    String? reason,
  }) {
    return _guard(() async {
      final model = await remoteDataSource.createReassignment(
        insuranceAssignmentId: insuranceAssignmentId,
        toUserId: toUserId,
        reason: reason,
      );
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, List<InsuranceReassignment>>> listReassignments({
    String? status,
    RequestCancelToken? cancelToken,
  }) {
    return _guard(() async {
      final models = await remoteDataSource.listReassignments(
        status: status,
        cancelToken: cancelToken.asDioCancelToken(),
      );
      return models.map((m) => m.toEntity()).toList();
    });
  }
}
