import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/json_file_cache.dart';

/// Un caché por contenedor. Los tests lo sustituyen por [MemoryJsonFileCache].
final jsonFileCacheProvider = Provider<JsonFileCache>((ref) {
  return DiskJsonFileCache();
});
