import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/material_programa.dart';
import 'materiales_providers.dart';

/// Lista de programas (tipos de club) disponibles en el catálogo.
///
/// keepAlive: los programas son estables durante la sesión de usuario — se
/// evita re-fetching innecesario al navegar entre pantallas.
final programasProvider = FutureProvider<List<MaterialPrograma>>((ref) async {
  ref.keepAlive();

  final repo = ref.read(materialesRepositoryProvider);
  final result = await repo.listProgramas();
  return result.fold(
    (failure) => throw Exception(failure.message),
    (programas) => programas,
  );
});
