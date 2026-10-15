import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/widgets/instructor_selection.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor_update.dart';

void main() {
  group('PATCH body of /users/:userId/honors/:honorId', () {
    test('a person is camelCase instructorUserId only', () {
      expect(
        honorInstructorPatch(
            const InstructorSelection.user(id: 'u-1', displayName: 'Ana')),
        {'instructorUserId': 'u-1'},
      );
    });

    test('a typed name is instructorName only', () {
      expect(
        honorInstructorPatch(const InstructorSelection.external('Juan López')),
        {'instructorName': 'Juan López'},
      );
    });

    test('removing sends null for both', () {
      final patch = honorInstructorPatch(const InstructorSelection.none());
      expect(patch, {'instructorUserId': null, 'instructorName': null});
      expect(patch.containsKey('instructorUserId'), isTrue);
    });

    test('the completion date is yyyy-mm-dd, padded', () {
      expect(honorCompletedAtPatch(DateTime(2026, 3, 5)),
          {'completedAt': '2026-03-05'});
      expect(honorCompletedAtPatch(DateTime(1960, 1, 1)),
          {'completedAt': '1960-01-01'});
    });
  });
}
