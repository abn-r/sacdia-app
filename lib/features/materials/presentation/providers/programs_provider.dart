import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/material_program.dart';
import 'materials_providers.dart';

/// Lista de programas (tipos de club) disponibles en el catálogo.
///
/// keepAlive: los programas son estables durante la sesión de usuario — se
/// evita re-fetching innecesario al navegar entre pantallas.
final programsProvider = FutureProvider<List<MaterialProgram>>((ref) async {
  ref.keepAlive();

  final repo = ref.read(materialsRepositoryProvider);
  final result = await repo.listPrograms();
  return result.fold(
    (failure) => throw Exception(failure.message),
    (programs) => programs,
  );
});
