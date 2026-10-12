import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/widgets/instructor_selection.dart';
import 'package:sacdia_app/features/honors/data/models/user_honor_model.dart';

Map<String, dynamic> _json([Map<String, dynamic> extra = const {}]) => {
      'user_honor_id': 10,
      'honor_id': 7,
      'user_id': 'user-1',
      'validation_status': 'IN_PROGRESS',
      'certificate': '',
      'images': [],
      'document': null,
      'date': '2026-06-11T00:00:00.000Z',
      ...extra,
    };

void main() {
  group('completed_at', () {
    test('reads a date-only value as that calendar day', () {
      final model =
          UserHonorModel.fromJson(_json({'completed_at': '2026-09-30'}));
      expect(model.completedAt, DateTime(2026, 9, 30));
      expect(model.toEntity().completedAt, DateTime(2026, 9, 30));
    });

    test('reads a UTC midnight timestamp as the same day, not the day before',
        () {
      final model = UserHonorModel.fromJson(
        _json({'completed_at': '2026-09-30T00:00:00.000Z'}),
      );
      expect(model.completedAt, DateTime(2026, 9, 30));
    });

    test('tolerates a missing, null or unreadable value', () {
      expect(UserHonorModel.fromJson(_json()).completedAt, isNull);
      expect(UserHonorModel.fromJson(_json({'completed_at': null})).completedAt,
          isNull);
      expect(
          UserHonorModel.fromJson(_json({'completed_at': 'mañana'}))
              .completedAt,
          isNull);
    });

    test('is written back as yyyy-mm-dd', () {
      final json =
          UserHonorModel.fromJson(_json({'completed_at': '2026-03-05'}))
              .toJson();
      expect(json['completed_at'], '2026-03-05');
    });

    test('the day to show is completed_at, else validated_at, else the start',
        () {
      final started = DateTime.utc(2026, 6, 11);
      expect(
        UserHonorModel.fromJson(_json({
          'completed_at': '2026-09-30',
          'validated_at': '2026-10-02T10:00:00.000Z',
        })).toEntity().completionDate,
        DateTime(2026, 9, 30),
      );
      expect(
        UserHonorModel.fromJson(
                _json({'validated_at': '2026-10-02T10:00:00.000Z'}))
            .toEntity()
            .completionDate,
        DateTime.parse('2026-10-02T10:00:00.000Z'),
      );
      expect(
          UserHonorModel.fromJson(_json()).toEntity().completionDate, started);
    });
  });

  group('instructor', () {
    test('a person of the Local Field', () {
      final model = UserHonorModel.fromJson(_json({
        'instructor': {
          'kind': 'USER',
          'user_id': 'u-1',
          'display_name': 'Ana Gómez',
        },
        'instructor_user_id': 'u-1',
        'instructor_name': null,
      }));
      expect(
        model.toEntity().instructor,
        const InstructorSelection.user(id: 'u-1', displayName: 'Ana Gómez'),
      );
    });

    test('keeps the photo when the response has one (single-row responses)',
        () {
      final model = UserHonorModel.fromJson(_json({
        'instructor': {
          'kind': 'USER',
          'user_id': 'u-1',
          'display_name': 'Ana Gómez',
          'photo_url': 'https://r2.example/p.jpg',
        },
      }));
      expect(model.instructor?.photoUrl, 'https://r2.example/p.jpg');
    });

    test('a typed name is external', () {
      final model = UserHonorModel.fromJson(_json({
        'instructor': {'kind': 'EXTERNAL', 'display_name': 'Juan López'},
      }));
      expect(
          model.instructor, const InstructorSelection.external('Juan López'));
    });

    test('no block means no instructor (old backend or none declared)', () {
      expect(UserHonorModel.fromJson(_json()).instructor, isNull);
      expect(UserHonorModel.fromJson(_json({'instructor': null})).instructor,
          isNull);
    });

    test('falls back to the raw typed name when the block is absent', () {
      final model =
          UserHonorModel.fromJson(_json({'instructor_name': 'Juan López'}));
      expect(
          model.instructor, const InstructorSelection.external('Juan López'));
    });

    test('a block that cannot be read is no instructor, never a crash', () {
      for (final block in <Object?>[
        'oops',
        <String, dynamic>{},
        {'kind': 'USER', 'display_name': 'Sin id'},
        {'kind': 'ALIEN', 'display_name': 'X', 'user_id': 'u'},
        {'kind': 'USER', 'user_id': 'u', 'display_name': '  '},
      ]) {
        expect(UserHonorModel.fromJson(_json({'instructor': block})).instructor,
            isNull,
            reason: '$block');
      }
    });

    test('copyWith keeps them', () {
      final model = UserHonorModel.fromJson(_json({
        'completed_at': '2026-09-30',
        'instructor': {'kind': 'EXTERNAL', 'display_name': 'Juan López'},
      })).copyWith(validationStatus: 'REJECTED');
      expect(model.completedAt, DateTime(2026, 9, 30));
      expect(
          model.instructor, const InstructorSelection.external('Juan López'));
    });
  });
}
