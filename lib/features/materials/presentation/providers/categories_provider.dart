import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/material_category.dart';
import 'materials_providers.dart';

/// Lista de categorías activas.
///
/// keepAlive: los datos de catálogo son estables durante la sesión — se
/// evita re-fetching innecesario cuando el usuario navega entre pantallas.
final categoriesProvider = FutureProvider<List<MaterialCategory>>((ref) async {
  ref.keepAlive();

  final repo = ref.read(materialsRepositoryProvider);
  final result = await repo.listCategories();
  return result.fold(
    (failure) => throw Exception(failure.message),
    (categories) => categories,
  );
});
