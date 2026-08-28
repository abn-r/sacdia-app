import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/cancel_token_adapter.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../../../camporee_orders/domain/entities/camporee_order.dart';
import '../../domain/entities/camporee_supply_plan.dart';
import '../../domain/repositories/camporee_supplies_repository.dart';
import '../datasources/camporee_supplies_remote_data_source.dart';

class CamporeeSuppliesRepositoryImpl implements CamporeeSuppliesRepository {
  final CamporeeSuppliesRemoteDataSource remoteDataSource;

  CamporeeSuppliesRepositoryImpl({required this.remoteDataSource});

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
  Future<Either<Failure, CamporeeSupplyPlanEnvelope>> getPlan({
    required int camporeeId,
    CamporeeKind camporeeType = CamporeeKind.local,
    RequestCancelToken? cancelToken,
  }) {
    return _guard(
      () => remoteDataSource.getPlan(
        camporeeId: camporeeId,
        camporeeType: camporeeType,
        cancelToken: cancelToken.asDioCancelToken(),
      ),
    );
  }

  @override
  Future<Either<Failure, CamporeeSupplyPlan>> replaceDraft({
    required int camporeeId,
    required List<CamporeeSupplyLineInput> lines,
    CamporeeKind camporeeType = CamporeeKind.local,
  }) {
    return _guard(
      () => remoteDataSource.replaceDraft(
        camporeeId: camporeeId,
        lines: lines,
        camporeeType: camporeeType,
      ),
    );
  }

  @override
  Future<Either<Failure, CamporeeSupplyPlan>> submit({
    required int camporeeId,
    CamporeeKind camporeeType = CamporeeKind.local,
  }) {
    return _guard(
      () => remoteDataSource.submit(
        camporeeId: camporeeId,
        camporeeType: camporeeType,
      ),
    );
  }

  @override
  Future<Either<Failure, CamporeeSupplyPlan>> adjustLine({
    required int camporeeId,
    required CamporeeSupplyLineInput line,
    CamporeeKind camporeeType = CamporeeKind.local,
  }) {
    return _guard(
      () => remoteDataSource.adjustLine(
        camporeeId: camporeeId,
        line: line,
        camporeeType: camporeeType,
      ),
    );
  }
}
