import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/orden.dart';
import '../../domain/usecases/get_order_history.dart';
import 'materiales_providers.dart';

/// Provider del historial de órdenes del usuario autenticado.
///
/// Carga la primera página (20 registros). autoDispose para limpiar al salir.
/// Usar [ref.invalidateSelf()] para hacer pull-to-refresh.
final historialProvider =
    FutureProvider.autoDispose<List<Orden>>((ref) async {
  final useCase = ref.read(getOrderHistoryUseCaseProvider);
  final result = await useCase(
    const GetOrderHistoryParams(page: 1, pageSize: 20),
  );
  return result.fold(
    (failure) => throw Exception(failure.message),
    (list) => list,
  );
});
