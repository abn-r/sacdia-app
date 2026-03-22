import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/member_insurance.dart';
import '../repositories/insurance_repository.dart';

/// Parámetros para obtener seguros por vencer.
class GetExpiringInsuranceParams extends Equatable {
  /// Cantidad de días hacia adelante para considerar un seguro "por vencer".
  final int days;

  const GetExpiringInsuranceParams({this.days = 30});

  @override
  List<Object> get props => [days];
}

/// Caso de uso: obtiene seguros que vencen en los próximos [days] días.
///
/// Llama a GET /api/v1/insurance/expiring.
class GetExpiringInsurance {
  final InsuranceRepository _repository;

  const GetExpiringInsurance(this._repository);

  Future<Either<Failure, List<MemberInsurance>>> call(
      GetExpiringInsuranceParams params) {
    return _repository.getExpiringInsurance(days: params.days);
  }
}
