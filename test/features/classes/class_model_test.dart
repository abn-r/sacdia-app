import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/classes/data/models/class_model.dart';

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
  });
}
