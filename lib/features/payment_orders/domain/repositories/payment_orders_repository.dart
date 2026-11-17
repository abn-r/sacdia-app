import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../entities/payment_order.dart';

/// Contrato del repositorio de órdenes de pago territoriales.
abstract class PaymentOrdersRepository {
  Future<Either<Failure, PaymentOrdersContext>> getContext({
    RequestCancelToken? cancelToken,
  });

  /// [idempotencyKey] makes a retry of the same request return the same
  /// order instead of issuing a second one.
  ///
  /// Fails with `DuplicateBeneficiariesFailure` when someone is no longer
  /// free (already insured elsewhere or in another open order).
  Future<Either<Failure, PaymentOrder>> createInsuranceOrder({
    required int cycleConfigId,
    required List<String> beneficiaryUserIds,
    String? idempotencyKey,
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

  /// Signed URL to open the order's latest proof of payment.
  Future<Either<Failure, String>> getProofUrl(String orderId);

  Future<Either<Failure, PaymentOrder>> uploadProof({
    required String orderId,
    required String filePath,
    required String fileName,
    required String mimeType,
  });

  Future<Either<Failure, PaymentOrder>> cancelOrder(String orderId);

  /// Passes a free insurance to someone else. The server executes it at once.
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
