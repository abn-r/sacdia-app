import 'package:sacdia_app/core/widgets/instructor_selection.dart';

/// Body of `PATCH /users/:userId/honors/:honorId` for the instructor. This
/// endpoint is camelCase (the certificate import one is snake_case). The two
/// fields are exclusive: a value in one makes the API clear the other, `null`
/// removes it.
Map<String, dynamic> honorInstructorPatch(InstructorSelection instructor) =>
    switch (instructor.kind) {
      InstructorKind.user => {'instructorUserId': instructor.userId},
      InstructorKind.external => {'instructorName': instructor.displayName},
      InstructorKind.none => {
          'instructorUserId': null,
          'instructorName': null,
        },
    };

/// Body for the day the member finished the honor (`yyyy-mm-dd`).
Map<String, dynamic> honorCompletedAtPatch(DateTime completedAt) => {
      'completedAt': '${completedAt.year.toString().padLeft(4, '0')}-'
          '${completedAt.month.toString().padLeft(2, '0')}-'
          '${completedAt.day.toString().padLeft(2, '0')}',
    };

/// Business codes the PATCH can answer that the screen explains.
abstract final class HonorUpdateErrorCode {
  static const invalidStatus = 'VALIDATION_HONOR_INVALID_STATUS';
  static const dateTooOld = 'HONOR_DATE_TOO_OLD';
  static const dateInFuture = 'HONOR_DATE_IN_FUTURE';
}
