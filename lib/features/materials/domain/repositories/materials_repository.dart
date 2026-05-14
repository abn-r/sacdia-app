import 'dart:io';

import 'package:dartz/dartz.dart' hide Order;

import '../../../../core/errors/failures.dart';
import '../entities/receipt.dart';
import '../entities/material_category.dart';
import '../entities/material_config.dart';
import '../entities/material_delivery.dart';
import '../entities/material_item.dart';
import '../entities/material_program.dart';
import '../entities/order.dart';

/// Contrato del repositorio de Materiales.
///
/// Todas las operaciones devuelven [Either<Failure, T>] para manejar
/// errores de forma funcional sin excepciones sin tratar.
abstract class MaterialsRepository {
  // ── Catálogo ───────────────────────────────────────────────────────────────

  /// Obtiene productos del catálogo con filtros opcionales.
  Future<Either<Failure, List<MaterialItem>>> browseCatalog({
    String? cat,
    int? programaId,
    String? q,
    int page = 1,
    int pageSize = 20,
  });

  /// Obtiene el detalle completo de un producto por su ID.
  Future<Either<Failure, MaterialItem>> getProductDetail(String id);

  /// Lista todas las categorías activas.
  Future<Either<Failure, List<MaterialCategory>>> listCategories();

  /// Lista los programas (tipos de club) disponibles.
  Future<Either<Failure, List<MaterialProgram>>> listPrograms();

  // ── Órdenes ────────────────────────────────────────────────────────────────

  /// Crea una nueva orden de materiales.
  ///
  /// [lines] es la lista de líneas: producto + variante opcional + cantidad.
  Future<Either<Failure, Order>> createOrder({
    required int clubSectionId,
    required List<({String productId, String? variantOptionId, int qty})> lines,
    required MaterialDelivery delivery,
    String? notas,
  });

  /// Lista órdenes (visibilidad controlada por el backend según permisos).
  Future<Either<Failure, List<Order>>> listOrders({
    String? status,
    int page = 1,
    int pageSize = 20,
  });

  /// Historial de órdenes propias del usuario autenticado.
  Future<Either<Failure, List<Order>>> getOrderHistory({
    int page = 1,
    int pageSize = 20,
  });

  /// Obtiene una orden por su folio o ID.
  Future<Either<Failure, Order>> getOrderByFolio(String folioOrId);

  /// Cancela una orden con un motivo.
  Future<Either<Failure, Order>> cancelOrder(String folioOrId, String reason);

  // ── Receipts ──────────────────────────────────────────────────────────────

  /// Lista los comprobantes de una orden.
  Future<Either<Failure, List<Receipt>>> listReceipts(String folioOrId);

  /// Sube un comprobante de pago para una orden aprobada.
  Future<Either<Failure, Receipt>> uploadReceipt({
    required String folioOrId,
    required File file,
    required int montoCentavos,
    required String refBancariaDeclarada,
    required DateTime fechaPago,
    void Function(double)? onProgress,
  });

  // ── Configuración ──────────────────────────────────────────────────────────

  /// Obtiene la configuración bancaria y de entrega del módulo.
  Future<Either<Failure, MaterialConfig>> getConfig();
}
