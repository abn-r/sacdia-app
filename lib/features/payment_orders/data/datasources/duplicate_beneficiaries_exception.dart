import '../../../../core/errors/exceptions.dart';
import '../../../insurance/domain/entities/insurance_conflict.dart';

/// 409 `FIELD_PAYMENT_ORDER_DUPLICATE_BENEFICIARY` with the people who are no
/// longer free and why.
class DuplicateBeneficiariesException extends ServerException {
  DuplicateBeneficiariesException({
    required super.message,
    required this.conflicts,
    super.code,
    super.errorCode,
  });

  final List<InsuranceConflict> conflicts;
}
