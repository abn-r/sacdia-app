import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/profile_scope_registry.dart';
import '../../../../core/storage/image_cache_purge.dart';
import '../../../../core/storage/json_file_cache.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../providers/json_file_cache_provider.dart';
import '../../../../providers/storage_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../../home_widgets/next_activity_widget_sync.dart';
import '../../../post_registration/data/health_none_disk_cache.dart';
import '../../../virtual_card/data/virtual_card_disk_cache.dart';

/// Lista de providers que se invalidan al cambiar de perfil.
///
/// Es un provider para que los tests puedan sustituirla por centinelas sin
/// montar las decenas de dependencias reales del registro.
final profileScopedProvidersProvider = Provider<List<ProviderOrFamily>>(
  (ref) => profileScopedProviders,
);

/// Invalida TODO el estado en memoria de un perfil (FP-48).
///
/// Es síncrono a propósito: el llamador cambia la sesión y purga en el mismo
/// tramo síncrono, así cualquier provider que se reconstruya por la
/// invalidación ya sale con el encabezado y la generación del perfil nuevo.
void purgeProfileScopeProviders(Ref ref) {
  for (final provider in ref.read(profileScopedProvidersProvider)) {
    // A provider that was never mounted holds no state. Invalidating it from a
    // provider Ref makes debug builds instantiate it, which can fire network
    // calls during logout or a profile switch.
    if (provider is ProviderBase<Object?> && !ref.exists(provider)) continue;
    ref.invalidate(provider);
  }
}

/// Borra los cachés de disco que dependen del perfil: clases del usuario,
/// resumen del dashboard, credenciales virtuales guardadas y el widget de la
/// próxima actividad (FP-48, FP-51), y las marcas de salud "ninguna" de todo
/// usuario que no sea el tutor ([guardianUserId]; nulo = ninguna se conserva).
///
/// Con [clearImages] también vacía los cachés de imágenes (fotos y evidencias
/// del dependiente). Se pide al SALIR de un dependiente y al arrancar tras
/// morir actuando; al entrar no hace falta: lo que hay en disco es del tutor.
///
/// Nunca lanza: una purga que falla no debe dejar al usuario atascado a medio
/// cambio de perfil.
Future<void> purgeProfileScopeDiskCaches(
  Ref ref, {
  String? guardianUserId,
  bool clearImages = false,
}) async {
  try {
    await Future.wait<void>([
      ref
          .read(jsonFileCacheProvider)
          .deleteByPrefix(kUserClassesCacheKeyPrefix),
      clearDashboardSummaryDiskCache(ref.read(localStorageProvider)),
      clearVirtualCardDiskCache(ref.read(localStorageProvider)),
      clearHealthNoneFlags(
        ref.read(localStorageProvider),
        keepUserId: guardianUserId,
      ),
      clearNextActivityWidget(),
      if (clearImages) ref.read(imageCachePurgerProvider)(),
    ]);
  } catch (e, st) {
    AppLogger.e(
      'No se pudieron purgar los cachés de disco del perfil',
      tag: 'ProfileScopePurge',
      error: e,
      stackTrace: st,
    );
  }
}
