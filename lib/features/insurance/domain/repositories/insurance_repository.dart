import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../entities/insurance_overview.dart';
import '../entities/member_insurance.dart';

/// Reads of the insurance module.
abstract class InsuranceRepository {
  /// Year, cost, counts and every person of the section with their status.
  Future<Either<Failure, InsuranceOverview>> getOverview({
    required int sectionId,
    RequestCancelToken? cancelToken,
  });

  /// Coverages whose holder left the club and can be passed on.
  Future<Either<Failure, List<FreeCoverage>>> getFreeCoverages({
    required int sectionId,
    RequestCancelToken? cancelToken,
  });

  /// Legacy list, only for the camporee registration of fields that still
  /// do not use payment orders.
  Future<Either<Failure, List<MemberInsurance>>> getMembersInsurance({
    required int clubId,
    required int sectionId,
    RequestCancelToken? cancelToken,
  });
}
