import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../payment_orders/domain/entities/payment_order.dart';

enum InsuranceConflictReason {
  alreadyCovered,
  inLiveOrder;

  static InsuranceConflictReason fromApi(String? value) => switch (value) {
        'in_live_order' => InsuranceConflictReason.inLiveOrder,
        _ => InsuranceConflictReason.alreadyCovered,
      };
}

/// Someone the server refused to put in the order (409
/// `FIELD_PAYMENT_ORDER_DUPLICATE_BENEFICIARY`).
class InsuranceConflict extends Equatable {
  const InsuranceConflict({
    required this.userId,
    required this.name,
    required this.reason,
    this.sectionName,
    this.clubName,
    this.folio,
    this.validUntil,
    this.orderStatus,
  });

  final String userId;
  final String name;
  final InsuranceConflictReason reason;
  final String? sectionName;
  final String? clubName;
  final String? folio;
  final DateTime? validUntil;
  final PaymentOrderStatus? orderStatus;

  @override
  List<Object?> get props => [
        userId,
        name,
        reason,
        sectionName,
        clubName,
        folio,
        validUntil,
        orderStatus,
      ];
}

/// The order could not be issued because some people are no longer free.
class DuplicateBeneficiariesFailure extends Failure {
  const DuplicateBeneficiariesFailure({
    required super.message,
    required this.conflicts,
    super.code,
    super.errorCode,
  });

  final List<InsuranceConflict> conflicts;

  @override
  List<Object?> get props => [...super.props, conflicts];
}
