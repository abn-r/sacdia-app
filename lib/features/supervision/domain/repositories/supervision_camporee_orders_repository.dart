import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../../../camporee_orders/domain/entities/camporee_order_offering.dart';
import '../entities/supervision_camporee_orders.dart';

abstract class SupervisionCamporeeOrdersRepository {
  Future<Either<Failure, SupervisionCamporeeOrderConfig>> getOrderConfig(
    int camporeeId, {
    RequestCancelToken? cancelToken,
  });

  Future<Either<Failure, CamporeeOrderSettings>> updateOrderSettings(
    int camporeeId,
    SupervisionOrderSettingsPatch patch,
  );

  Future<Either<Failure, CamporeeOrderOfferingsCatalog>> replaceOfferings(
    int camporeeId,
    List<SupervisionOfferingInput> items,
  );

  Future<Either<Failure, SupervisionSupplyCatalog>> getSupplyCatalog(
    int camporeeId, {
    RequestCancelToken? cancelToken,
  });

  Future<Either<Failure, SupervisionSupplyCatalog>> updateSupplyCutoff(
    int camporeeId,
    String hhmm,
  );

  Future<Either<Failure, SupervisionSupplySlot>> createSupplySlot(
    int camporeeId, {
    required String label,
    required String deliverTime,
  });

  Future<Either<Failure, SupervisionSupplySlot>> updateSupplySlot(
    int camporeeId,
    String slotId, {
    String? label,
    String? deliverTime,
    bool? active,
  });

  Future<Either<Failure, SupervisionSupplyProduct>> createSupplyProduct(
    int camporeeId, {
    required String name,
    required SupervisionSupplyUom uom,
    required int unitCostCentavos,
  });

  Future<Either<Failure, SupervisionSupplyProduct>> updateSupplyProduct(
    int camporeeId,
    String productId, {
    String? name,
    SupervisionSupplyUom? uom,
    int? unitCostCentavos,
    bool? active,
  });
}
