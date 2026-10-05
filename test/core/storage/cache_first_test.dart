import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/storage/cache_first.dart';
import 'package:sacdia_app/core/storage/json_file_cache.dart';
import 'package:sacdia_app/features/classes/data/models/class_model.dart';
import 'package:sacdia_app/features/classes/domain/entities/class_prerequisite.dart';
import 'package:sacdia_app/features/classes/domain/entities/progressive_class.dart';
import 'package:sacdia_app/features/honors/data/models/honor_group_model.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor_category.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor_group.dart';
import 'package:sacdia_app/providers/json_file_cache_provider.dart';

int fetchCalls = 0;
String fetchValue = 'fresh';
bool fetchFails = false;

final probeProvider = FutureProvider<String>((ref) {
  return cacheFirst<String>(
    ref: ref,
    cache: ref.read(jsonFileCacheProvider),
    key: 'probe',
    refreshAfter: const Duration(hours: 24),
    decode: (payload) => payload as String,
    encode: (value) => value,
    fetch: () async {
      fetchCalls++;
      if (fetchFails) throw Exception('down');
      return fetchValue;
    },
  );
});

final childProvider = FutureProvider<String>((ref) async {
  return ref.watch(probeProvider.future);
});

void main() {
  setUp(() {
    fetchCalls = 0;
    fetchValue = 'fresh';
    fetchFails = false;
  });

  test('a fresh file is returned without calling the network', () async {
    final cache = MemoryJsonFileCache();
    await cache.write('probe', 'saved');
    final container = _container(cache);
    addTearDown(container.dispose);

    final value = await container.read(probeProvider.future);

    expect(value, 'saved');
    expect(fetchCalls, 0);
  });

  test('invalidate after a fresh file goes to the network', () async {
    final cache = MemoryJsonFileCache();
    await cache.write('probe', 'saved');
    fetchValue = 'live';
    final container = _container(cache);
    addTearDown(container.dispose);

    expect(await container.read(probeProvider.future), 'saved');
    container.invalidate(probeProvider);
    expect(await container.read(probeProvider.future), 'live');
    expect(fetchCalls, 1);
  });

  test('a stale file paints immediately and then updates listeners', () async {
    final cache = MemoryJsonFileCache();
    await cache.write(
      'probe',
      'old',
      cachedAt: DateTime.now().subtract(const Duration(days: 2)),
    );
    fetchValue = 'new';
    final container = _container(cache);
    addTearDown(container.dispose);
    container.listen(probeProvider, (_, __) {});
    container.listen(childProvider, (_, __) {});

    expect(await container.read(probeProvider.future), 'old');

    String? latest;
    for (var i = 0; i < 30 && latest != 'new'; i++) {
      await Future<void>.delayed(Duration.zero);
      latest = container.read(probeProvider).asData?.value;
    }

    expect(latest, 'new');
    expect(container.read(childProvider).asData?.value, 'new');
    expect(fetchCalls, 1);
  });

  test('a failed refresh keeps the stale file on screen', () async {
    final cache = MemoryJsonFileCache();
    await cache.write(
      'probe',
      'old',
      cachedAt: DateTime.now().subtract(const Duration(days: 2)),
    );
    fetchFails = true;
    final container = _container(cache);
    addTearDown(container.dispose);
    container.listen(probeProvider, (_, __) {});

    expect(await container.read(probeProvider.future), 'old');
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    final state = container.read(probeProvider);
    expect(state.hasError, isFalse);
    expect(state.asData?.value, 'old');
    expect(fetchCalls, 1);
  });

  test('class and honor cache payloads survive a json roundtrip', () {
    final classItem = ProgressiveClass(
      id: 1,
      name: 'Amigo',
      clubTypeId: 2,
      ecclesiasticalYearLabel: '2025–2026',
      overallProgress: 40,
      enrollmentDate: DateTime.utc(2026, 1, 2),
      prerequisites: const [
        ClassPrerequisite(classId: 3, name: 'Pionero'),
      ],
    );
    final classes = decodeClassCache(
      jsonDecode(jsonEncode(encodeClassCache([classItem]))),
    );
    expect(classes.single.name, 'Amigo');
    expect(classes.single.ecclesiasticalYearLabel, '2025–2026');
    expect(classes.single.overallProgress, 40);
    expect(classes.single.enrollmentDate, classItem.enrollmentDate);
    expect(classes.single.prerequisites.single.name, 'Pionero');

    final group = HonorGroup(
      category:
          const HonorCategory(id: 4, name: 'Naturaleza', description: 'd'),
      honors: const [
        Honor(
          id: 8,
          name: 'Aves',
          categoryId: 4,
          imageUrl: 'https://cdn.example/a.png',
          clubTypeId: 2,
          skillLevel: 1,
        ),
      ],
    );
    final groups = decodeHonorGroupCache(
      jsonDecode(jsonEncode(encodeHonorGroupCache([group]))),
    );
    expect(groups.single.category.name, 'Naturaleza');
    expect(groups.single.honors.single.imageUrl, 'https://cdn.example/a.png');
    expect(groups.single.honors.single.clubTypeId, 2);
  });

  test('disk cache deletes user class files and keeps the catalog', () async {
    final dir = await Directory.systemTemp.createTemp('sacdia_json_cache');
    addTearDown(() => dir.delete(recursive: true));
    final cache = DiskJsonFileCache(directory: () async => dir);

    await cache.write(userClassesCacheKey('user-a'), {'n': 1});
    await cache.write(kHonorsGroupedCacheKey, {'n': 2});
    await cache.deleteByPrefix(kUserClassesCacheKeyPrefix);

    expect(await cache.read(userClassesCacheKey('user-a')), isNull);
    expect((await cache.read(kHonorsGroupedCacheKey))?.payload, isNotNull);

    await cache.deleteAll();
    expect(await cache.read(kHonorsGroupedCacheKey), isNull);
  });
}

ProviderContainer _container(JsonFileCache cache) {
  return ProviderContainer(
    overrides: [
      jsonFileCacheProvider.overrideWithValue(cache),
    ],
  );
}
