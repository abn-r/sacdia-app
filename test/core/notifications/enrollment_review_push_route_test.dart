import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/notifications/enrollment_review_push_route.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';

const _adult =
    UserEntity(id: 'u-1', email: 'a@b.c', postRegisterComplete: true);

const _teen = UserEntity(
  id: 'u-2',
  email: 't@b.c',
  principal: PrincipalInfo(
    kind: PrincipalKind.supervisedUser,
    supervision: SupervisionInfo(status: SupervisionStatus.active),
  ),
);

void main() {
  group('club_enrollment_reviewed routing', () {
    test('recognises the push type and the inbox source', () {
      expect(
          isClubEnrollmentReviewedPushType('club_enrollment_reviewed'), isTrue);
      expect(isClubEnrollmentReviewedPushType('membership_request_created'),
          isFalse);
      expect(isClubEnrollmentReviewedPushType(null), isFalse);
      expect(
          isClubEnrollmentReviewedSource('club-enrollments:reviewed'), isTrue);
      expect(isClubEnrollmentReviewedSource('club-enrollments:other'), isFalse);
    });

    test('an adult account lands on the dashboard', () {
      expect(
        enrollmentReviewedRouteFor(_adult, acting: false),
        RouteNames.homeDashboard,
      );
    });

    test('nothing opens while acting for a dependent', () {
      expect(enrollmentReviewedRouteFor(_adult, acting: true), isNull);
    });

    test('nothing opens without a session or for a supervised teen', () {
      expect(enrollmentReviewedRouteFor(null, acting: false), isNull);
      expect(enrollmentReviewedRouteFor(_teen, acting: false), isNull);
    });
  });
}
