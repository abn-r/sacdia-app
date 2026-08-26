import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../../../payment_orders/domain/entities/payment_obligation.dart';
import '../entities/camporee_order.dart';
import '../entities/camporee_order_offering.dart';
import '../entities/camporee_order_product.dart';

/// Contrato de pedidos de mercancía de camporee (no inscripción).
abstract class CamporeeOrdersRepository {
  Future<Either<Failure, CamporeeOrderOfferingsCatalog>> getOfferings({
    required int camporeeId,
    CamporeeKind camporeeType = CamporeeKind.local,
    RequestCancelToken? cancelToken,
  });

  Future<Either<Failure, List<CamporeeOrderProduct>>> listProducts({
    RequestCancelToken? cancelToken,
  });

  Future<Either<Failure, CamporeeOrder>> createOrder({
    required int camporeeId,
    required List<CamporeeOrderLineInput> lines,
    CamporeeKind camporeeType = CamporeeKind.local,
    String? idempotencyKey,
  });

  Future<Either<Failure, List<CamporeeOrder>>> listOrders({
    int? camporeeId,
    int? unionCamporeeId,
    CamporeeOrderStatus? status,
    RequestCancelToken? cancelToken,
  });

  Future<Either<Failure, CamporeeOrder>> getOrder(
    String orderId, {
    RequestCancelToken? cancelToken,
  });

  Future<Either<Failure, String>> downloadOrderPdf(
    String orderId, {
    RequestCancelToken? cancelToken,
  });

  Future<Either<Failure, CamporeeOrderProofDownload>> getProof(
    String orderId, {
    RequestCancelToken? cancelToken,
  });

  Future<Either<Failure, CamporeeOrder>> uploadProof({
    required String orderId,
    required String filePath,
    required String fileName,
    required String mimeType,
  });

  Future<Either<Failure, CamporeeOrder>> cancelOrder(String orderId);

  Future<Either<Failure, CamporeeOrder>> deliverLineToMember({
    required String orderId,
    required String lineId,
  });

  Future<Either<Failure, List<PaymentObligation>>> listPendingObligations({
    int? camporeeId,
    int? unionCamporeeId,
    RequestCancelToken? cancelToken,
  });
}
