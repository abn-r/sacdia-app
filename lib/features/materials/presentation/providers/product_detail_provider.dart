import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/material_item.dart';
import '../../domain/usecases/get_product_detail.dart';
import 'materials_providers.dart';

/// Provider family que obtiene el detalle de un producto por su ID.
///
/// Uso:
/// ```dart
/// final itemAsync = ref.watch(productDetailProvider('abc-123'));
/// ```
final productDetailProvider =
    FutureProvider.autoDispose.family<MaterialItem, String>((ref, id) async {
  final useCase = ref.read(getProductDetailUseCaseProvider);
  final result = await useCase(GetProductDetailParams(id: id));
  return result.fold(
    (failure) => throw Exception(failure.message),
    (item) => item,
  );
});
