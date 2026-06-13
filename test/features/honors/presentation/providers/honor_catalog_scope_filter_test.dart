import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';

void main() {
  test('filters honors by catalog scope before applying category filter',
      () async {
    final container = ProviderContainer(
      overrides: [
        activeHonorCatalogScopeProvider.overrideWith(
          (ref) => const AsyncValue.data(null),
        ),
        allHonorsProvider.overrideWith(
          (ref) async => const [
            Honor(
              id: 1,
              name: 'Contar historias bíblicas',
              categoryId: 0,
              clubTypeId: 1,
            ),
            Honor(
              id: 2,
              name: 'Arte de acampar',
              categoryId: 7,
              clubTypeId: 2,
            ),
            Honor(
              id: 3,
              name: 'Mayordomía',
              categoryId: 6,
              clubTypeId: 3,
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(allHonorsProvider.future);

    container.read(selectedHonorCatalogScopeProvider.notifier).state =
        HonorCatalogScope.adventurers;
    expect(
      container.read(filteredHonorsProvider).value!.map((h) => h.id),
      [1],
    );

    container.read(selectedHonorCatalogScopeProvider.notifier).state =
        HonorCatalogScope.pathfindersAndMasterGuides;
    expect(
      container.read(filteredHonorsProvider).value!.map((h) => h.id),
      [2, 3],
    );

    container.read(selectedCategoryProvider.notifier).state = 7;
    expect(
      container.read(filteredHonorsProvider).value!.map((h) => h.id),
      [2],
    );
  });

  test('locks catalog to the active Adventurer section', () async {
    final container = ProviderContainer(
      overrides: [
        activeHonorCatalogScopeProvider.overrideWith(
          (ref) => const AsyncValue.data(HonorCatalogScope.adventurers),
        ),
        allHonorsProvider.overrideWith(
          (ref) async => const [
            Honor(
              id: 1,
              name: 'Corderito de lana',
              categoryId: 0,
              clubTypeId: 1,
            ),
            Honor(
              id: 2,
              name: 'Arte de acampar',
              categoryId: 7,
              clubTypeId: 2,
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(allHonorsProvider.future);
    container.read(selectedHonorCatalogScopeProvider.notifier).state =
        HonorCatalogScope.pathfindersAndMasterGuides;

    expect(
      container.read(filteredHonorsProvider).value!.map((h) => h.id),
      [1],
    );
  });

  test('filters user honor progress by active Pathfinder/GM section', () async {
    final now = DateTime(2026, 6, 12);
    final container = ProviderContainer(
      overrides: [
        activeHonorCatalogScopeProvider.overrideWith(
          (ref) => const AsyncValue.data(
              HonorCatalogScope.pathfindersAndMasterGuides),
        ),
        userHonorsProvider.overrideWith(
          (ref) async => [
            UserHonor(
              id: 1,
              honorId: 1,
              userId: 'user-1',
              date: now,
              honorClubTypeId: 1,
            ),
            UserHonor(
              id: 2,
              honorId: 2,
              userId: 'user-1',
              date: now,
              honorClubTypeId: 2,
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(userHonorsProvider.future);
    final honors = container.read(sectionScopedUserHonorsProvider).value!;
    expect(honors.map((h) => h.honorId), [2]);
  });
}
