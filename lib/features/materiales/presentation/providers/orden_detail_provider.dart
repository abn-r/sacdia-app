import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/orden.dart';
import '../../domain/usecases/get_order_detail.dart';
import 'materiales_providers.dart';

/// Provider family que obtiene el detalle de una orden por folio o ID.
///
/// autoDispose: se limpia al abandonar la pantalla de detalle.
///
/// Uso:
/// ```dart
/// final ordenAsync = ref.watch(ordenDetailProvider('abc-123'));
/// ```
final ordenDetailProvider =
    FutureProvider.autoDispose.family<Orden, String>((ref, folioOrId) async {
  final useCase = ref.read(getOrderDetailUseCaseProvider);
  final result = await useCase(GetOrderDetailParams(folioOrId: folioOrId));
  return result.fold(
    (failure) => throw Exception(failure.message),
    (orden) => orden,
  );
});
