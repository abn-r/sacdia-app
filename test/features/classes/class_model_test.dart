import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/classes/data/models/class_model.dart';
import 'package:sacdia_app/features/classes/domain/entities/class_prerequisite.dart';

void main() {
  group('ClassModel availability and duration', () {
    test('parses missing legacy fields with backward-compatible defaults', () {
      final model = ClassModel.fromJson(const {
        'class_id': 7,
        'name': 'Amigo',
        'club_type_id': 2,
      });

      expect(model.availableFromYearId, isNull);
      expect(model.availableUntilYearId, isNull);
      expect(model.minDurationYears, 1);
      expect(model.maxDurationYears, 1);

      final entity = model.toEntity();
      expect(entity.availableFromYearId, isNull);
      expect(entity.availableUntilYearId, isNull);
      expect(entity.minDurationYears, 1);
      expect(entity.maxDurationYears, 1);
    });

    test('parses explicit availability and duration fields', () {
      final model = ClassModel.fromJson(const {
        'class_id': 8,
        'name': 'Guía Mayor Instructor',
        'club_type_id': 3,
        'available_from_year_id': 2026,
        'available_until_year_id': 2028,
        'min_duration_years': 2,
        'max_duration_years': 3,
      });

      expect(model.availableFromYearId, 2026);
      expect(model.availableUntilYearId, 2028);
      expect(model.minDurationYears, 2);
      expect(model.maxDurationYears, 3);
      expect(model.toJson(), containsPair('available_from_year_id', 2026));
      expect(model.toJson(), containsPair('available_until_year_id', 2028));
      expect(model.toJson(), containsPair('min_duration_years', 2));
      expect(model.toJson(), containsPair('max_duration_years', 3));
    });

    test('preserves enrollment id from user enrollment responses', () {
      final model = ClassModel.fromJson(const {
        'class_id': 13,
        'name': 'Guía',
        'club_type_id': 2,
        'enrollment_id': 901,
        'investiture_status': 'EXPIRED',
      });

      expect(model.enrollmentId, 901);
      expect(model.toEntity().enrollmentId, 901);
      expect(model.toJson(), containsPair('enrollment_id', 901));
    });

    test('parses optional investiture enrollment fields when present', () {
      final model = ClassModel.fromJson(const {
        'class_id': 6,
        'name': 'Guía',
        'club_type_id': 1,
        'enrollment_id': 42,
        'investiture_status': 'INVESTIDO',
        'overall_progress': 100,
        'enrollment_date': '2025-03-01T12:00:00.000Z',
        'submitted_at': '2025-10-15T12:00:00.000Z',
        'validated_at': '2025-11-20T12:00:00.000Z',
        'ecclesiastical_year': {
          'start_date': '2025-01-01T00:00:00.000Z',
          'end_date': '2026-12-31T00:00:00.000Z',
        },
      });

      expect(model.enrollmentDate, DateTime.parse('2025-03-01T12:00:00.000Z'));
      expect(model.submittedAt, DateTime.parse('2025-10-15T12:00:00.000Z'));
      expect(model.validatedAt, DateTime.parse('2025-11-20T12:00:00.000Z'));
      expect(model.ecclesiasticalYearLabel, '2025–2026');

      final entity = model.toEntity();
      expect(entity.enrollmentDate, model.enrollmentDate);
      expect(entity.submittedAt, model.submittedAt);
      expect(entity.validatedAt, model.validatedAt);
      expect(entity.ecclesiasticalYearLabel, '2025–2026');
    });
  });

  group('ClassModel prerequisites', () {
    test('defaults to an empty list when prerequisites is absent', () {
      final model = ClassModel.fromJson(const {
        'class_id': 9,
        'name': 'Compañero',
        'club_type_id': 2,
      });

      expect(model.prerequisites, isEmpty);
      expect(model.toEntity().prerequisites, isEmpty);
    });

    test('parses active prerequisites with class_id and name', () {
      final model = ClassModel.fromJson(const {
        'class_id': 10,
        'name': 'Explorador',
        'club_type_id': 2,
        'prerequisites': [
          {'class_id': 7, 'name': 'Amigo'},
          {'class_id': 9, 'name': 'Compañero'},
        ],
      });

      expect(model.prerequisites, hasLength(2));
      expect(
        model.prerequisites,
        containsAll(const [
          ClassPrerequisite(classId: 7, name: 'Amigo'),
          ClassPrerequisite(classId: 9, name: 'Compañero'),
        ]),
      );

      final entity = model.toEntity();
      expect(entity.prerequisites, model.prerequisites);
    });

    test('ignores malformed prerequisite entries gracefully', () {
      final model = ClassModel.fromJson(const {
        'class_id': 11,
        'name': 'Piloneros',
        'club_type_id': 2,
        'prerequisites': 'not-a-list',
      });

      expect(model.prerequisites, isEmpty);
    });
  });
}
