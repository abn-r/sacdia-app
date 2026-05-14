import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/material_config.dart';
import 'materials_providers.dart';

/// Provider de la configuración del módulo de materiales.
///
/// keepAlive: la config es estable durante la sesión — no necesitamos refetch
/// entre navegaciones dentro del flujo de pedidos.
final configProvider = FutureProvider<MaterialConfig>((ref) async {
  ref.keepAlive();
  final useCase = ref.read(getConfigUseCaseProvider);
  final result = await useCase();
  return result.fold(
    (failure) => throw Exception(failure.message),
    (config) => config,
  );
});
