import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/classes/data/models/class_members_progress_result_model.dart';

void main() {
  group('ClassMemberProgressModel.fromJson — cross_type_enrollment', () {
    Map<String, dynamic> _baseJson({Object? crossTypeEnrollment}) => {
          'user_id': 'user-abc',
          'name': 'Ana Torres',
          'enrollment_id': 42,
          'class_id': 7,
          'ecclesiastical_year_id': 2026,
          'investiture_status': 'NONE',
          'completed_sections': 3,
          'total_sections': 8,
          'overall_progress': 37,
          if (crossTypeEnrollment != null)
            'cross_type_enrollment': crossTypeEnrollment,
        };

    test('defaults to false when field is absent', () {
      final model = ClassMemberProgressModel.fromJson(_baseJson());
      expect(model.crossTypeEnrollment, isFalse);
    });

    test('parses true when field is true', () {
      final model =
          ClassMemberProgressModel.fromJson(_baseJson(crossTypeEnrollment: true));
      expect(model.crossTypeEnrollment, isTrue);
    });

    test('stays false when field is explicitly false', () {
      final model = ClassMemberProgressModel.fromJson(
          _baseJson(crossTypeEnrollment: false));
      expect(model.crossTypeEnrollment, isFalse);
    });

    test('stays false when field is a non-true value (e.g. null)', () {
      final model =
          ClassMemberProgressModel.fromJson(_baseJson(crossTypeEnrollment: null));
      expect(model.crossTypeEnrollment, isFalse);
    });

    test('toJson round-trips crossTypeEnrollment', () {
      final model = ClassMemberProgressModel.fromJson(
          _baseJson(crossTypeEnrollment: true));
      expect(model.toJson()['cross_type_enrollment'], isTrue);
    });

    test('toEntity propagates crossTypeEnrollment', () {
      final model = ClassMemberProgressModel.fromJson(
          _baseJson(crossTypeEnrollment: true));
      expect(model.toEntity().crossTypeEnrollment, isTrue);
    });

    test('props includes crossTypeEnrollment for equality', () {
      final a = ClassMemberProgressModel.fromJson(
          _baseJson(crossTypeEnrollment: true));
      final b = ClassMemberProgressModel.fromJson(
          _baseJson(crossTypeEnrollment: false));
      expect(a, isNot(equals(b)));
    });
  });
}
