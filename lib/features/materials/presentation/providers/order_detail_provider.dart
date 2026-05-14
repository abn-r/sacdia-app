import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/order.dart';
import '../../domain/usecases/get_order_detail.dart';
import 'materials_providers.dart';

/// Provider family que obtiene el detalle de una orden por folio o ID.
///
/// autoDispose: se limpia al abandonar la pantalla de detalle.
///
/// Uso:
/// ```dart
/// final orderAsync = ref.watch(orderDetailProvider('abc-123'));
/// ```
final orderDetailProvider =
    FutureProvider.autoDispose.family<Order, String>((ref, folioOrId) async {
  final useCase = ref.read(getOrderDetailUseCaseProvider);
  final result = await useCase(GetOrderDetailParams(folioOrId: folioOrId));
  return result.fold(
    (failure) => throw Exception(failure.message),
    (order) => order,
  );
});
