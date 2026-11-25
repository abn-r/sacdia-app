import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/cancel_token_adapter.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../../../camporee_orders/domain/entities/camporee_order_offering.dart';
import '../../domain/entities/supervision_camporee_orders.dart';
import '../../domain/repositories/supervision_camporee_orders_repository.dart';
import '../datasources/supervision_camporee_orders_remote_data_source.dart';

class SupervisionCamporeeOrdersRepositoryImpl
    implements SupervisionCamporeeOrdersRepository {
  final SupervisionCamporeeOrdersRemoteDataSource remoteDataSource;

  SupervisionCamporeeOrdersRepositoryImpl({required this.remoteDataSource});

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() call) async {
    try {
      return Right(await call());
    } on ServerException catch (e) {
      return Left(ServerFailure(
          message: e.message, code: e.code, errorCode: e.errorCode));
    } on AuthException catch (e) {
      return Left(AuthFailure(
          message: e.message, code: e.code, errorCode: e.errorCode));
    } on ConnectionException catch (e) {
      return Left(ConnectionFailure(message: e.message));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, SupervisionCamporeeOrderConfig>> getOrderConfig(
    int camporeeId, {
    RequestCancelToken? cancelToken,
  }) =>
      _guard(() => remoteDataSource.getOrderConfig(
            camporeeId,
            cancelToken: cancelToken.asDioCancelToken(),
          ));

  @override
  Future<Either<Failure, CamporeeOrderSettings>> updateOrderSettings(
    int camporeeId,
    SupervisionOrderSettingsPatch patch,
  ) =>
      _guard(() => remoteDataSource.updateOrderSettings(camporeeId, patch));

  @override
  Future<Either<Failure, CamporeeOrderOfferingsCatalog>> replaceOfferings(
    int camporeeId,
    List<SupervisionOfferingInput> items,
  ) =>
      _guard(() => remoteDataSource.replaceOfferings(camporeeId, items));

  @override
  Future<Either<Failure, SupervisionSupplyCatalog>> getSupplyCatalog(
    int camporeeId, {
    RequestCancelToken? cancelToken,
  }) =>
      _guard(() => remoteDataSource.getSupplyCatalog(
            camporeeId,
            cancelToken: cancelToken.asDioCancelToken(),
          ));

  @override
  Future<Either<Failure, SupervisionSupplyCatalog>> updateSupplyCutoff(
    int camporeeId,
    String hhmm,
  ) =>
      _guard(() => remoteDataSource.updateSupplyCutoff(camporeeId, hhmm));

  @override
  Future<Either<Failure, SupervisionSupplySlot>> createSupplySlot(
    int camporeeId, {
    required String label,
    required String deliverTime,
  }) =>
      _guard(() => remoteDataSource.createSupplySlot(
            camporeeId,
            label: label,
            deliverTime: deliverTime,
          ));

  @override
  Future<Either<Failure, SupervisionSupplySlot>> updateSupplySlot(
    int camporeeId,
    String slotId, {
    String? label,
    String? deliverTime,
    bool? active,
  }) =>
      _guard(() => remoteDataSource.updateSupplySlot(
            camporeeId,
            slotId,
            label: label,
            deliverTime: deliverTime,
            active: active,
          ));

  @override
  Future<Either<Failure, SupervisionSupplyProduct>> createSupplyProduct(
    int camporeeId, {
    required String name,
    required SupervisionSupplyUom uom,
    required int unitCostCentavos,
  }) =>
      _guard(() => remoteDataSource.createSupplyProduct(
            camporeeId,
            name: name,
            uom: uom,
            unitCostCentavos: unitCostCentavos,
          ));

  @override
  Future<Either<Failure, SupervisionSupplyProduct>> updateSupplyProduct(
    int camporeeId,
    String productId, {
    String? name,
    SupervisionSupplyUom? uom,
    int? unitCostCentavos,
    bool? active,
  }) =>
      _guard(() => remoteDataSource.updateSupplyProduct(
            camporeeId,
            productId,
            name: name,
            uom: uom,
            unitCostCentavos: unitCostCentavos,
            active: active,
          ));
}
