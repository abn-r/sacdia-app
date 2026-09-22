import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../utils/app_logger.dart';

/// Catálogo de especialidades agrupadas. No depende del usuario.
const String kHonorsGroupedCacheKey = 'honors_grouped';

/// Prefijo de las clases de un usuario. La clave completa incluye el userId.
const String kUserClassesCacheKeyPrefix = 'user_classes_';

/// Catálogo de clases, sin progreso de un usuario.
const String kAllClassesCacheKey = 'classes_all';

String userClassesCacheKey(String userId) =>
    '$kUserClassesCacheKeyPrefix$userId';

String classesByClubTypeCacheKey(int clubTypeId) =>
    'classes_club_type_$clubTypeId';

class CachedJsonFile {
  final Object? payload;
  final DateTime cachedAt;

  const CachedJsonFile({required this.payload, required this.cachedAt});
}

/// Estado de esta ejecución. El archivo puede existir, pero un invalidate
/// dentro del mismo proceso tiene que ir a la red.
class JsonCacheSession {
  final Set<String> builtKeys = {};
  final Map<String, Object?> stagedPayloads = {};
  final Set<String> refreshesInFlight = {};

  bool hasBuilt(String key) => builtKeys.contains(key);

  void markBuilt(String key) => builtKeys.add(key);

  void stage(String key, Object? payload) => stagedPayloads[key] = payload;

  /// Devuelve false si no había un valor recién bajado esperando al rebuild.
  bool takeStaged(String key, void Function(Object? payload) onPayload) {
    if (!stagedPayloads.containsKey(key)) return false;
    onPayload(stagedPayloads.remove(key));
    return true;
  }

  void reset() {
    builtKeys.clear();
    stagedPayloads.clear();
    refreshesInFlight.clear();
  }

  void forgetPrefix(String prefix) {
    builtKeys.removeWhere((key) => key.startsWith(prefix));
    stagedPayloads.removeWhere((key, _) => key.startsWith(prefix));
    refreshesInFlight.removeWhere((key) => key.startsWith(prefix));
  }
}

abstract class JsonFileCache {
  final JsonCacheSession session = JsonCacheSession();

  Future<CachedJsonFile?> read(String key);

  Future<void> write(String key, Object? payload, {DateTime? cachedAt});

  Future<void> deleteByPrefix(String prefix);

  Future<void> deleteAll();

  void resetSession() => session.reset();
}

String encodeCacheEnvelope(Object? payload, DateTime cachedAt) {
  return jsonEncode({
    'cached_at': cachedAt.millisecondsSinceEpoch,
    'payload': payload,
  });
}

CachedJsonFile? decodeCacheEnvelope(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map) return null;
  final map = Map<String, dynamic>.from(decoded);
  final cachedAtMs = map['cached_at'];
  if (cachedAtMs is! int) return null;
  return CachedJsonFile(
    payload: map['payload'],
    cachedAt: DateTime.fromMillisecondsSinceEpoch(cachedAtMs),
  );
}

class MemoryJsonFileCache extends JsonFileCache {
  final Map<String, String> _files = {};

  @override
  Future<CachedJsonFile?> read(String key) async {
    final raw = _files[key];
    if (raw == null) return null;
    try {
      return decodeCacheEnvelope(raw);
    } catch (_) {
      _files.remove(key);
      return null;
    }
  }

  @override
  Future<void> write(String key, Object? payload, {DateTime? cachedAt}) async {
    _files[key] = encodeCacheEnvelope(payload, cachedAt ?? DateTime.now());
  }

  @override
  Future<void> deleteByPrefix(String prefix) async {
    _files.removeWhere((key, _) => key.startsWith(prefix));
    session.forgetPrefix(prefix);
  }

  @override
  Future<void> deleteAll() async {
    _files.clear();
    session.reset();
  }
}

class DiskJsonFileCache extends JsonFileCache {
  DiskJsonFileCache({Future<Directory> Function()? directory})
      : _directory = directory;

  final Future<Directory> Function()? _directory;

  static const _tag = 'JsonFileCache';

  Future<Directory?> _openDir() async {
    try {
      final Directory dir;
      if (_directory != null) {
        dir = await _directory!();
      } else {
        final support = await getApplicationSupportDirectory();
        dir = Directory('${support.path}/sacdia_json_cache');
      }
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    } catch (e) {
      AppLogger.w('No se pudo abrir el caché en disco', tag: _tag, error: e);
      return null;
    }
  }

  String _fileName(String key) {
    final safe = key.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return '$safe.json';
  }

  @override
  Future<CachedJsonFile?> read(String key) async {
    try {
      final dir = await _openDir();
      if (dir == null) return null;
      final file = File('${dir.path}/${_fileName(key)}');
      if (!await file.exists()) return null;
      return decodeCacheEnvelope(await file.readAsString());
    } catch (e) {
      AppLogger.w('Lectura de caché falló para $key', tag: _tag, error: e);
      return null;
    }
  }

  @override
  Future<void> write(String key, Object? payload, {DateTime? cachedAt}) async {
    try {
      final dir = await _openDir();
      if (dir == null) return;
      final file = File('${dir.path}/${_fileName(key)}');
      await file.writeAsString(
        encodeCacheEnvelope(payload, cachedAt ?? DateTime.now()),
      );
    } catch (e) {
      AppLogger.w('Escritura de caché falló para $key', tag: _tag, error: e);
    }
  }

  @override
  Future<void> deleteByPrefix(String prefix) async {
    session.forgetPrefix(prefix);
    try {
      final dir = await _openDir();
      if (dir == null) return;
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (name.startsWith(prefix) && name.endsWith('.json')) {
          await entity.delete();
        }
      }
    } catch (e) {
      AppLogger.w('Borrado por prefijo falló ($prefix)', tag: _tag, error: e);
    }
  }

  @override
  Future<void> deleteAll() async {
    session.reset();
    try {
      final dir = await _openDir();
      if (dir == null || !await dir.exists()) return;
      await for (final entity in dir.list(followLinks: false)) {
        await entity.delete(recursive: true);
      }
    } catch (e) {
      AppLogger.w('Borrado del caché en disco falló', tag: _tag, error: e);
    }
  }
}
