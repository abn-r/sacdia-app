import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/storage/json_file_cache.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/classes/data/models/class_model.dart';
import 'package:sacdia_app/features/classes/domain/entities/progressive_class.dart';
import 'package:sacdia_app/features/classes/domain/repositories/classes_repository.dart';
import 'package:sacdia_app/features/classes/presentation/providers/classes_providers.dart';
import 'package:sacdia_app/providers/json_file_cache_provider.dart';

class _FakeClassesRepository implements ClassesRepository {
  int getClassesCalls = 0;
  List<ProgressiveClass> catalog = const [];

  @override
  Future<Either<Failure, List<ProgressiveClass>>> getClasses({
    int? clubTypeId,
    RequestCancelToken? cancelToken,
  }) async {
    getClassesCalls++;
    return Right(catalog);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _seedClass = ProgressiveClass(
  id: 99,
  name: 'Guía Mayor - Nivel 1 (Seed)',
  clubTypeId: 3,
);
const _realClass = ProgressiveClass(id: 7, name: 'Guía Mayor', clubTypeId: 3);

void main() {
  test('a fresh catalog file paints first and is revalidated behind', () async {
    final cache = MemoryJsonFileCache();
    await cache.write(kAllClassesCacheKey, encodeClassCache([_seedClass]));
    final repository = _FakeClassesRepository()..catalog = [_realClass];
    final container = ProviderContainer(
      overrides: [
        jsonFileCacheProvider.overrideWithValue(cache),
        classesRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    container.listen(allClassesProvider, (_, __) {});

    final first = await container.read(allClassesProvider.future);
    expect(first.single.name, _seedClass.name);

    List<ProgressiveClass>? latest;
    for (var i = 0; i < 30 && latest?.single.id != _realClass.id; i++) {
      await Future<void>.delayed(Duration.zero);
      latest = container.read(allClassesProvider).asData?.value;
    }

    expect(latest?.single.name, _realClass.name);
    expect(repository.getClassesCalls, 1);
    final saved = await cache.read(kAllClassesCacheKey);
    expect(decodeClassCache(saved?.payload).single.id, _realClass.id);
  });

  test('invalidate after the first read goes to the network', () async {
    final cache = MemoryJsonFileCache();
    final repository = _FakeClassesRepository()..catalog = [_seedClass];
    final container = ProviderContainer(
      overrides: [
        jsonFileCacheProvider.overrideWithValue(cache),
        classesRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    container.listen(allClassesProvider, (_, __) {});

    await container.read(allClassesProvider.future);
    repository.catalog = [_realClass];
    container.invalidate(allClassesProvider);

    final refreshed = await container.read(allClassesProvider.future);
    expect(refreshed.single.id, _realClass.id);
    expect(repository.getClassesCalls, 2);
  });
}
