import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/post_registration/data/models/class_model.dart';
import 'package:sacdia_app/features/post_registration/data/models/club_section_model.dart';
import 'package:sacdia_app/features/post_registration/presentation/utils/club_selection_age_rules.dart';

void main() {
  group('club selection age rules', () {
    final sections = const [
      ClubSectionModel(
        id: 1,
        clubTypeId: 1,
        clubId: 10,
        clubTypeSlug: 'adventurers',
        clubTypeName: 'Aventureros',
      ),
      ClubSectionModel(
        id: 2,
        clubTypeId: 2,
        clubId: 10,
        clubTypeSlug: 'pathfinders',
        clubTypeName: 'Conquistadores',
      ),
      ClubSectionModel(
        id: 3,
        clubTypeId: 3,
        clubId: 10,
        clubTypeSlug: 'master_guild',
        clubTypeName: 'Guías Mayores',
      ),
    ];

    test('calculates age from the full birthdate', () {
      final today = DateTime(2026, 6, 24);

      expect(
        calculateAgeFromBirthdate(DateTime(2000, 1, 1), today: today),
        26,
      );
      expect(
        calculateAgeFromBirthdate(DateTime(2013, 12, 1), today: today),
        12,
      );
    });

    test('calculates age using the ecclesiastical year start date', () {
      final ecclesiasticalYearStart = DateTime(2026, 1, 1);
      final birthdayAfterYearStart = DateTime(2013, 6, 24);

      expect(
        calculateAgeFromBirthdate(
          birthdayAfterYearStart,
          today: ecclesiasticalYearStart,
        ),
        12,
      );
      expect(
        calculateAgeFromBirthdate(
          birthdayAfterYearStart,
          today: DateTime(2026, 6, 24),
        ),
        13,
      );
    });

    test('recommends club section by SACDIA age ranges', () {
      expect(recommendedClubSectionForAge(sections, 4)?.id, 1);
      expect(recommendedClubSectionForAge(sections, 9)?.id, 1);
      expect(recommendedClubSectionForAge(sections, 10)?.id, 2);
      expect(recommendedClubSectionForAge(sections, 15)?.id, 2);
      expect(recommendedClubSectionForAge(sections, 16)?.id, 3);
      expect(recommendedClubSectionForAge(sections, 26)?.id, 3);
    });

    test('selects class from minimum age when max age is absent', () {
      final classes = const [
        ClassModel(id: 10, name: 'Amigo', minAge: 10, clubTypeId: 2),
        ClassModel(id: 11, name: 'Compañero', minAge: 11, clubTypeId: 2),
        ClassModel(id: 12, name: 'Explorador', minAge: 12, clubTypeId: 2),
        ClassModel(id: 13, name: 'Orientador', minAge: 13, clubTypeId: 2),
      ];

      expect(
          recommendedProgressiveClassForAge(classes, 13)?.name, 'Orientador');
    });

    test('honors max age when the catalog provides age ranges', () {
      final classes = const [
        ClassModel(
          id: 1,
          name: 'Abejitas Laboriosas',
          minAge: 6,
          maxAge: 6,
          clubTypeId: 1,
        ),
        ClassModel(
          id: 2,
          name: 'Rayitos de Sol',
          minAge: 7,
          maxAge: 7,
          clubTypeId: 1,
        ),
      ];

      expect(recommendedProgressiveClassForAge(classes, 7)?.id, 2);
      expect(recommendedProgressiveClassForAge(classes, 8), isNull);
    });
  });
}
