import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/material_category.dart';
import 'materiales_providers.dart';

/// Lista de categorías activas.
///
/// keepAlive: los datos de catálogo son estables durante la sesión — se
/// evita re-fetching innecesario cuando el usuario navega entre pantallas.
final categoriasProvider =
    FutureProvider<List<MaterialCategory>>((ref) async {
  ref.keepAlive();

  final repo = ref.read(materialesRepositoryProvider);
  final result = await repo.listCategorias();
  return result.fold(
    (failure) => throw Exception(failure.message),
    (categories) => categories,
  );
});
