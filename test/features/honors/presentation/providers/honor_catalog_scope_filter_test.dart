import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';

void main() {
  test('filters honors by catalog scope before applying category filter',
      () async {
    final container = ProviderContainer(
      overrides: [
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
}
