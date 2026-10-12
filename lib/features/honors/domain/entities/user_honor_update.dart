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

/// Body of `POST /users/:userId/honors/:honorId/instructor-proposal` (camelCase,
/// exactly one of the two fields). [InstructorKind.none] has nothing to
/// propose: callers must not send it.
Map<String, dynamic> honorInstructorProposalBody(
  InstructorSelection instructor,
) =>
    switch (instructor.kind) {
      InstructorKind.user => {'instructorUserId': instructor.userId},
      InstructorKind.external => {'instructorName': instructor.displayName},
      InstructorKind.none => throw ArgumentError('Nothing to propose'),
    };

/// Business codes the proposal endpoints answer that the card explains.
abstract final class InstructorProposalErrorCode {
  static const unchanged = 'HONOR_INSTRUCTOR_UNCHANGED';
  static const required = 'HONOR_INSTRUCTOR_REQUIRED';
  static const notApproved = 'HONOR_INSTRUCTOR_PROPOSAL_NOT_APPROVED';
  static const notFound = 'HONOR_INSTRUCTOR_PROPOSAL_NOT_FOUND';
  static const notPending = 'HONOR_INSTRUCTOR_PROPOSAL_NOT_PENDING';
  static const forbidden = 'HONOR_INSTRUCTOR_PROPOSAL_FORBIDDEN';

  /// The honor or the proposal is no longer what the screen drew: re-read it.
  static const Set<String> stale = {notApproved, notFound, notPending};
}
