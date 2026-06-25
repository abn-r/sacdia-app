import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/post_registration/data/models/class_model.dart';
import 'package:sacdia_app/features/post_registration/data/models/club_section_model.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/club_selection_providers.dart';

void main() {
  group('club selection providers', () {
    test('parses backend club section shape used by post-registration', () {
      final section = ClubSectionModel.fromJson({
        'club_section_id': 2,
        'active': true,
        'name': null,
        'club_types': {
          'club_type_id': 2,
          'name': 'Conquistadores',
        },
      });

      expect(section.id, 2);
      expect(section.clubTypeId, 2);
      expect(section.clubId, 0);
      expect(section.clubTypeSlug, 'pathfinders');
      expect(section.displayName, 'Conquistadores');
    });

    test('derive club section from age without a manual override state',
        () async {
      final container = ProviderContainer(
        overrides: [
          userAgeProvider.overrideWith((ref) => 12),
          selectedClubProvider.overrideWith((ref) => 10),
          clubSectionsProvider.overrideWith((ref) async {
            return [
              ClubSectionModel.fromJson({
                'club_section_id': 1,
                'club_types': {
                  'club_type_id': 1,
                  'name': 'Aventureros',
                },
              }),
              ClubSectionModel.fromJson({
                'club_section_id': 2,
                'club_types': {
                  'club_type_id': 2,
                  'name': 'Conquistadores',
                },
              }),
              ClubSectionModel.fromJson({
                'club_section_id': 3,
                'club_types': {
                  'club_type_id': 3,
                  'name': 'Guías Mayores',
                },
              }),
            ];
          }),
        ],
      );
      addTearDown(container.dispose);

      await container.read(clubSectionsProvider.future);

      expect(container.read(selectedClubSectionProvider), 2);
      expect(container.read(selectedClubTypeSlugProvider), 'pathfinders');
    });

    test('derive progressive class from age without a manual override state',
        () async {
      final container = ProviderContainer(
        overrides: [
          userAgeProvider.overrideWith((ref) => 12),
          selectedClubProvider.overrideWith((ref) => 10),
          clubSectionsProvider.overrideWith((ref) async {
            return [
              ClubSectionModel.fromJson({
                'club_section_id': 2,
                'club_types': {
                  'club_type_id': 2,
                  'name': 'Conquistadores',
                },
              }),
            ];
          }),
          classesProvider.overrideWith((ref) async {
            return const [
              ClassModel(
                id: 10,
                name: 'Amigo',
                minAge: 10,
                clubTypeId: 2,
              ),
              ClassModel(
                id: 11,
                name: 'Compañero',
                minAge: 11,
                clubTypeId: 2,
              ),
              ClassModel(
                id: 12,
                name: 'Explorador',
                minAge: 12,
                clubTypeId: 2,
              ),
              ClassModel(
                id: 13,
                name: 'Orientador',
                minAge: 13,
                clubTypeId: 2,
              ),
            ];
          }),
        ],
      );
      addTearDown(container.dispose);

      await container.read(clubSectionsProvider.future);
      await container.read(classesProvider.future);

      expect(container.read(selectedClassProvider), 12);
    });
  });
}
