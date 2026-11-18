import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/material_status.dart';
import '../../domain/entities/order.dart';
import '../../domain/usecases/get_order_history.dart';
import 'materials_providers.dart';

/// Provider del historial de órdenes del usuario autenticado.
///
/// Carga la primera página (20 registros). autoDispose para limpiar al salir.
/// Usar [ref.invalidateSelf()] para hacer pull-to-refresh.
///
/// El listado no trae los comprobantes. Para las órdenes aprobadas (las únicas
/// donde el comprobante decide si falta pagar, si se revisa o si lo rechazaron)
/// se piden aparte, en paralelo; si alguna petición falla la orden queda sin
/// comprobantes y se trata como "falta pagar".
final historyProvider = FutureProvider.autoDispose<List<Order>>((ref) async {
  final useCase = ref.read(getOrderHistoryUseCaseProvider);
  final result = await useCase(
    const GetOrderHistoryParams(page: 1, pageSize: 20),
  );
  final orders = result.fold(
    (failure) => throw Exception(failure.message),
    (list) => list,
  );

  final repo = ref.read(materialsRepositoryProvider);
  return Future.wait(
    orders.map((order) async {
      if (order.status != MaterialStatus.aprobada ||
          order.receipts.isNotEmpty) {
        return order;
      }
      try {
        final result = await repo.listReceipts(order.routeKey);
        final withReceipts =
            result.fold((_) => order, (list) => order.copyWith(receipts: list));
        return withReceipts;
      } catch (_) {
        return order;
      }
    }),
  );
});
