import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';

void main() {
  const catalog = [
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
  ];

  ProviderContainer createContainer({int? activeClubTypeId}) {
    return ProviderContainer(
      overrides: [
        activeHonorCatalogClubTypeIdProvider.overrideWith(
          (ref) => AsyncValue.data(activeClubTypeId),
        ),
        allHonorsProvider.overrideWith((ref) async => catalog),
      ],
    );
  }

  test('falls back to all honors when there is no active section context',
      () async {
    final container = createContainer();
    addTearDown(container.dispose);

    await container.read(allHonorsProvider.future);

    expect(
      container.read(filteredHonorsProvider).value!.map((h) => h.id),
      [1, 2, 3],
    );

    container.read(selectedCategoryProvider.notifier).state = 7;
    expect(
      container.read(filteredHonorsProvider).value!.map((h) => h.id),
      [2],
    );
  });

  test('locks catalog to exact active Adventurer club type', () async {
    final container = createContainer(activeClubTypeId: 1);
    addTearDown(container.dispose);

    await container.read(allHonorsProvider.future);
    container.read(selectedCategoryProvider.notifier).state = 7;

    expect(
      container.read(filteredHonorsProvider).value!.map((h) => h.id),
      [1],
    );
  });

  test('locks catalog to exact active Pathfinder club type', () async {
    final container = createContainer(activeClubTypeId: 2);
    addTearDown(container.dispose);

    await container.read(allHonorsProvider.future);

    expect(
      container.read(filteredHonorsProvider).value!.map((h) => h.id),
      [2],
    );
  });

  test('allows Master Guide section to see Pathfinder and Master Guide honors',
      () async {
    final container = createContainer(activeClubTypeId: 3);
    addTearDown(container.dispose);

    await container.read(allHonorsProvider.future);

    expect(
      container.read(filteredHonorsProvider).value!.map((h) => h.id),
      [2, 3],
    );
  });

  test('filters user honor progress by active Master Guide section', () async {
    final now = DateTime(2026, 6, 12);
    final container = ProviderContainer(
      overrides: [
        activeHonorCatalogClubTypeIdProvider.overrideWith(
          (ref) => const AsyncValue.data(3),
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
            UserHonor(
              id: 3,
              honorId: 3,
              userId: 'user-1',
              date: now,
              honorClubTypeId: 3,
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(userHonorsProvider.future);
    final honors = container.read(sectionScopedUserHonorsProvider).value!;
    expect(honors.map((h) => h.honorId), [2, 3]);
  });
}
