import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'json_file_cache.dart';

/// Primera lectura del proceso: devuelve el archivo y, si ya venció
/// [refreshAfter], refresca detrás. Un rebuild posterior (invalidate) va a
/// la red. Si esa red falla y había archivo, la pantalla se queda con él.
Future<T> cacheFirst<T>({
  required Ref ref,
  required JsonFileCache cache,
  required String key,
  required Duration refreshAfter,
  required T Function(Object? payload) decode,
  required Object? Function(T value) encode,
  required Future<T> Function() fetch,
}) async {
  Object? staged;
  if (cache.session.takeStaged(key, (payload) => staged = payload)) {
    return decode(staged);
  }

  var disposed = false;
  ref.onDispose(() => disposed = true);

  final firstRead = !cache.session.hasBuilt(key);
  if (firstRead) {
    cache.session.markBuilt(key);
    final cached = await cache.read(key);
    if (cached != null) {
      try {
        final value = decode(cached.payload);
        final age = DateTime.now().difference(cached.cachedAt);
        if (age > refreshAfter) {
          unawaited(
            _refreshInBackground<T>(
              ref: ref,
              cache: cache,
              key: key,
              encode: encode,
              fetch: fetch,
              isDisposed: () => disposed,
            ),
          );
        }
        return value;
      } catch (_) {
        // Archivo ilegible: se sigue a la red.
      }
    }
  }

  final fresh = await fetch();
  await cache.write(key, encode(fresh));
  return fresh;
}

Future<void> _refreshInBackground<T>({
  required Ref ref,
  required JsonFileCache cache,
  required String key,
  required Object? Function(T value) encode,
  required Future<T> Function() fetch,
  required bool Function() isDisposed,
}) async {
  if (!cache.session.refreshesInFlight.add(key)) return;
  try {
    final fresh = await fetch();
    final payload = encode(fresh);
    await cache.write(key, payload);
    if (isDisposed()) return;
    cache.session.stage(key, payload);
    ref.invalidateSelf();
  } catch (_) {
    // El dato en pantalla sigue siendo el archivo.
  } finally {
    cache.session.refreshesInFlight.remove(key);
  }
}
