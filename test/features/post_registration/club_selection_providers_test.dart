import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/post_registration/data/models/class_model.dart';
import 'package:sacdia_app/features/post_registration/data/models/club_section_model.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/club_selection_providers.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/personal_info_providers.dart';
import 'package:sacdia_app/providers/catalogs_provider.dart';
import 'package:sacdia_app/shared/models/catalogs/ecclesiastical_year_model.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<UserEntity?> build() async => null;
}

class _UserAuthNotifier extends AuthNotifier {
  _UserAuthNotifier(this._user);

  final UserEntity _user;

  @override
  Future<UserEntity?> build() async => _user;
}

List<ClubSectionModel> _threeSections() => [
      ClubSectionModel.fromJson({
        'club_section_id': 1,
        'club_types': {'club_type_id': 1, 'name': 'Aventureros'},
      }),
      ClubSectionModel.fromJson({
        'club_section_id': 2,
        'club_types': {'club_type_id': 2, 'name': 'Conquistadores'},
      }),
      ClubSectionModel.fromJson({
        'club_section_id': 3,
        'club_types': {'club_type_id': 3, 'name': 'Guías Mayores'},
      }),
    ];

void main() {
  group('club selection providers', () {
    test(
        'user age falls back to the saved personal info snapshot once the '
        'personal info form is disposed', () async {
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
          currentEcclesiasticalYearProvider.overrideWith((ref) async {
            return EcclesiasticalYearModel(
              ecclesiasticalYearId: 1,
              name: '2025-2026',
              startDate: DateTime.utc(2026, 1, 1),
              endDate: DateTime.utc(2026, 12, 31),
              active: true,
            );
          }),
          personalInfoSnapshotProvider.overrideWith((ref) async {
            return PersonalInfoSnapshot(birthdate: DateTime.utc(2014, 10, 15));
          }),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(userAgeProvider, (_, __) {});
      addTearDown(subscription.close);
      await container.read(currentEcclesiasticalYearProvider.future);
      await container.read(personalInfoSnapshotProvider.future);

      expect(container.read(userAgeProvider), 11);
    });

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

    test('prefers the section where the user already holds an active role',
        () async {
      const director = UserEntity(
        id: 'director-1',
        authorization: AuthorizationSnapshot(
          clubAssignments: [
            AuthorizationGrant(
              assignmentId: 'a-1',
              roleName: 'director',
              clubId: 10,
              sectionId: 2,
              status: 'active',
            ),
          ],
        ),
      );
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(() => _UserAuthNotifier(director)),
          // 42 years old: age alone would pick Master Guides (section 3).
          userAgeProvider.overrideWith((ref) => 42),
          selectedClubProvider.overrideWith((ref) => 10),
          clubSectionsProvider.overrideWith((ref) async => _threeSections()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.future);
      await container.read(clubSectionsProvider.future);

      expect(container.read(selectedClubSectionProvider), 2);
      expect(container.read(selectedClubTypeSlugProvider), 'pathfinders');
    });

    test('an inactive role does not override the age rule', () async {
      const former = UserEntity(
        id: 'former-1',
        authorization: AuthorizationSnapshot(
          clubAssignments: [
            AuthorizationGrant(
              assignmentId: 'a-2',
              roleName: 'director',
              clubId: 10,
              sectionId: 2,
              status: 'inactive',
            ),
          ],
        ),
      );
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(() => _UserAuthNotifier(former)),
          userAgeProvider.overrideWith((ref) => 42),
          selectedClubProvider.overrideWith((ref) => 10),
          clubSectionsProvider.overrideWith((ref) async => _threeSections()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.future);
      await container.read(clubSectionsProvider.future);

      expect(container.read(selectedClubSectionProvider), 3);
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
