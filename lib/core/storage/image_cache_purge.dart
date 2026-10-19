import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/cache_config.dart';
import '../utils/app_logger.dart';

/// Vacía los cachés de imágenes (disco y memoria) que pueden guardar fotos y
/// evidencias de un dependiente: [SacCacheManager] y [SacProfileCacheManager],
/// más la caché decodificada de Flutter (FP-49, FP-53).
///
/// Nunca lanza: una purga fallida no debe bloquear la salida de perfil ni el
/// logout. [managers] existe para poder probarla sin disco.
Future<void> clearImageCaches({Iterable<BaseCacheManager>? managers}) async {
  for (final manager in managers ??
      <BaseCacheManager>[
        SacCacheManager.instance,
        SacProfileCacheManager.instance,
      ]) {
    try {
      await manager.emptyCache();
    } catch (e) {
      AppLogger.w(
        'No se pudo vaciar el caché de imágenes',
        tag: 'ImageCachePurge',
        error: e,
      );
    }
  }
  try {
    final cache = PaintingBinding.instance.imageCache;
    cache.clear();
    cache.clearLiveImages();
  } catch (e) {
    AppLogger.w(
      'No se pudo vaciar la caché de imágenes en memoria',
      tag: 'ImageCachePurge',
      error: e,
    );
  }
}

/// Punto de inyección de [clearImageCaches] para que los tests de salida de
/// perfil y logout no toquen el disco real.
final imageCachePurgerProvider = Provider<Future<void> Function()>(
  (ref) => clearImageCaches,
);
