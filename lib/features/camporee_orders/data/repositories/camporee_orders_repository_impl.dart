import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/cancel_token_adapter.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../../../payment_orders/domain/entities/payment_obligation.dart';
import '../../domain/entities/camporee_order.dart';
import '../../domain/entities/camporee_order_offering.dart';
import '../../domain/entities/camporee_order_product.dart';
import '../../domain/repositories/camporee_orders_repository.dart';
import '../datasources/camporee_orders_remote_data_source.dart';

class CamporeeOrdersRepositoryImpl implements CamporeeOrdersRepository {
  final CamporeeOrdersRemoteDataSource remoteDataSource;

  CamporeeOrdersRepositoryImpl({required this.remoteDataSource});

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
  Future<Either<Failure, CamporeeOrderOfferingsCatalog>> getOfferings({
    required int camporeeId,
    CamporeeKind camporeeType = CamporeeKind.local,
    RequestCancelToken? cancelToken,
  }) {
    return _guard(() async {
      final model = await remoteDataSource.getOfferings(
        camporeeId: camporeeId,
        camporeeType: camporeeType,
        cancelToken: cancelToken.asDioCancelToken(),
      );
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, List<CamporeeOrderProduct>>> listProducts({
    RequestCancelToken? cancelToken,
  }) {
    return _guard(() async {
      final models = await remoteDataSource.listProducts(
        cancelToken: cancelToken.asDioCancelToken(),
      );
      return models.map((m) => m.toEntity()).toList();
    });
  }

  @override
  Future<Either<Failure, CamporeeOrder>> createOrder({
    required int camporeeId,
    required List<CamporeeOrderLineInput> lines,
    CamporeeKind camporeeType = CamporeeKind.local,
    String? idempotencyKey,
  }) {
    return _guard(() async {
      final model = await remoteDataSource.createOrder(
        camporeeId: camporeeId,
        lines: lines,
        camporeeType: camporeeType,
        idempotencyKey: idempotencyKey,
      );
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, List<CamporeeOrder>>> listOrders({
    int? camporeeId,
    int? unionCamporeeId,
    CamporeeOrderStatus? status,
    RequestCancelToken? cancelToken,
  }) {
    return _guard(() async {
      final models = await remoteDataSource.listOrders(
        camporeeId: camporeeId,
        unionCamporeeId: unionCamporeeId,
        status: status?.apiValue,
        cancelToken: cancelToken.asDioCancelToken(),
      );
      return models.map((m) => m.toEntity()).toList();
    });
  }

  @override
  Future<Either<Failure, CamporeeOrder>> getOrder(
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
  Future<Either<Failure, CamporeeOrderProofDownload>> getProof(
    String orderId, {
    RequestCancelToken? cancelToken,
  }) {
    return _guard(() async {
      final model = await remoteDataSource.getProof(
        orderId,
        cancelToken: cancelToken.asDioCancelToken(),
      );
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, CamporeeOrder>> uploadProof({
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
  Future<Either<Failure, CamporeeOrder>> cancelOrder(String orderId) {
    return _guard(() async {
      final model = await remoteDataSource.cancelOrder(orderId);
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, CamporeeOrder>> deliverLineToMember({
    required String orderId,
    required String lineId,
  }) {
    return _guard(() async {
      final model = await remoteDataSource.deliverLineToMember(
        orderId: orderId,
        lineId: lineId,
      );
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, List<PaymentObligation>>> listPendingObligations({
    int? camporeeId,
    int? unionCamporeeId,
    RequestCancelToken? cancelToken,
  }) {
    return _guard(() async {
      final models = await remoteDataSource.listPendingObligations(
        camporeeId: camporeeId,
        unionCamporeeId: unionCamporeeId,
        cancelToken: cancelToken.asDioCancelToken(),
      );
      return models.map((m) => m.toEntity()).toList();
    });
  }
}
