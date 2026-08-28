import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../entities/payment_order.dart';

/// Contrato del repositorio de órdenes de pago territoriales.
abstract class PaymentOrdersRepository {
  Future<Either<Failure, PaymentOrdersContext>> getContext({
    RequestCancelToken? cancelToken,
  });

  Future<Either<Failure, PaymentOrder>> createInsuranceOrder({
    required int cycleConfigId,
    required List<String> beneficiaryUserIds,
  });

  Future<Either<Failure, PaymentOrder>> createCamporeeOrder({
    required int camporeeId,
    required List<String> beneficiaryUserIds,
    String camporeeType = 'local',
  });

  Future<Either<Failure, List<PaymentOrder>>> listOrders({
    PaymentOrderPurpose? purpose,
    PaymentOrderStatus? status,
    int? camporeeId,
    int? unionCamporeeId,
    RequestCancelToken? cancelToken,
  });

  Future<Either<Failure, PaymentOrder>> getOrder(
    String orderId, {
    RequestCancelToken? cancelToken,
  });

  Future<Either<Failure, String>> downloadOrderPdf(
    String orderId, {
    RequestCancelToken? cancelToken,
  });

  Future<Either<Failure, PaymentOrder>> uploadProof({
    required String orderId,
    required String filePath,
    required String fileName,
    required String mimeType,
  });

  Future<Either<Failure, PaymentOrder>> cancelOrder(String orderId);

  Future<Either<Failure, InsuranceReassignment>> createReassignment({
    required int insuranceAssignmentId,
    required String toUserId,
    String? reason,
  });

  Future<Either<Failure, List<InsuranceReassignment>>> listReassignments({
    String? status,
    RequestCancelToken? cancelToken,
  });
}
