import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../../../camporee_orders/domain/entities/camporee_order.dart';
import '../entities/camporee_supply_plan.dart';

abstract class CamporeeSuppliesRepository {
  Future<Either<Failure, CamporeeSupplyPlanEnvelope>> getPlan({
    required int camporeeId,
    CamporeeKind camporeeType = CamporeeKind.local,
    RequestCancelToken? cancelToken,
  });

  Future<Either<Failure, CamporeeSupplyPlan>> replaceDraft({
    required int camporeeId,
    required List<CamporeeSupplyLineInput> lines,
    CamporeeKind camporeeType = CamporeeKind.local,
  });

  Future<Either<Failure, CamporeeSupplyPlan>> submit({
    required int camporeeId,
    CamporeeKind camporeeType = CamporeeKind.local,
  });

  Future<Either<Failure, CamporeeSupplyPlan>> adjustLine({
    required int camporeeId,
    required CamporeeSupplyLineInput line,
    CamporeeKind camporeeType = CamporeeKind.local,
  });
}
