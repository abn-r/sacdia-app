import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/comprobante.dart';
import '../entities/material_category.dart';
import '../entities/material_config.dart';
import '../entities/material_entrega.dart';
import '../entities/material_item.dart';
import '../entities/material_programa.dart';
import '../entities/orden.dart';

/// Contrato del repositorio de Materiales.
///
/// Todas las operaciones devuelven [Either<Failure, T>] para manejar
/// errores de forma funcional sin excepciones sin tratar.
abstract class MaterialesRepository {
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
  Future<Either<Failure, List<MaterialCategory>>> listCategorias();

  /// Lista los programas (tipos de club) disponibles.
  Future<Either<Failure, List<MaterialPrograma>>> listProgramas();

  // ── Órdenes ────────────────────────────────────────────────────────────────

  /// Crea una nueva orden de materiales.
  ///
  /// [lines] es la lista de líneas: producto + variante opcional + cantidad.
  Future<Either<Failure, Orden>> createOrder({
    required int clubSectionId,
    required List<({String productId, String? variantOptionId, int qty})> lines,
    required MaterialEntrega entrega,
    String? notas,
  });

  /// Lista órdenes (visibilidad controlada por el backend según permisos).
  Future<Either<Failure, List<Orden>>> listOrdenes({
    String? estado,
    int page = 1,
    int pageSize = 20,
  });

  /// Historial de órdenes propias del usuario autenticado.
  ///
  /// Alias de GET /ordenes/historial — siempre filtrado por created_by del caller.
  Future<Either<Failure, List<Orden>>> getOrderHistory({
    int page = 1,
    int pageSize = 20,
  });

  /// Obtiene una orden por su folio o ID.
  Future<Either<Failure, Orden>> getOrderByFolio(String folioOrId);

  /// Cancela una orden con un motivo.
  Future<Either<Failure, Orden>> cancelOrder(
      String folioOrId, String reason);

  // ── Comprobantes ──────────────────────────────────────────────────────────

  /// Lista los comprobantes de una orden.
  Future<Either<Failure, List<Comprobante>>> listComprobantes(
      String folioOrId);

  /// Sube un comprobante de pago para una orden aprobada.
  Future<Either<Failure, Comprobante>> uploadComprobante({
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
