import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../../../payment_orders/domain/entities/payment_obligation.dart';
import '../entities/camporee_order.dart';
import '../entities/camporee_order_offering.dart';
import '../entities/camporee_order_product.dart';

/// Contrato del repositorio de pedidos de mercancía de camporee.
abstract class CamporeeOrdersRepository {
  Future<Either<Failure, List<CamporeeOrder>>> listOrders({
    int? localCamporeeId,
    int? unionCamporeeId,
    CamporeeOrderStatus? status,
    RequestCancelToken? cancelToken,
  });

  Future<Either<Failure, CamporeeOrder>> getOrder(
    String orderId, {
    RequestCancelToken? cancelToken,
  });

  Future<Either<Failure, CamporeeOrder>> createOrder({
    required int camporeeId,
    required String camporeeType,
    required List<CamporeeOrderCreateLine> lines,
    String? idempotencyKey,
  });

  Future<Either<Failure, CamporeeOrderOfferingsResult>> getOfferings({
    required int camporeeId,
    required String camporeeType,
    RequestCancelToken? cancelToken,
  });

  Future<Either<Failure, List<CamporeeOrderProduct>>> listProducts({
    bool? active,
    RequestCancelToken? cancelToken,
  });

  Future<Either<Failure, String>> downloadOrderPdf(
    String orderId, {
    RequestCancelToken? cancelToken,
  });

  Future<Either<Failure, CamporeeOrder>> uploadProof({
    required String orderId,
    required String filePath,
    required String fileName,
    required String mimeType,
  });

  Future<Either<Failure, CamporeeOrderProof>> getProof(String orderId);

  Future<Either<Failure, CamporeeOrder>> cancelOrder(String orderId);

  Future<Either<Failure, CamporeeOrder>> deliverLineToMember({
    required String orderId,
    required String lineId,
  });

  /// GET /payment-obligations/pending — read model transversal, sin merge.
  Future<Either<Failure, List<PaymentObligation>>> listPendingObligations({
    int? camporeeId,
    int? unionCamporeeId,
    RequestCancelToken? cancelToken,
  });
}
