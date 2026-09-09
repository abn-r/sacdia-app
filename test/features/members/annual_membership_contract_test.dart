import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import 'package:sacdia_app/features/members/data/models/annual_continuation_model.dart';
import 'package:sacdia_app/features/members/domain/entities/annual_continuation.dart';

void main() {
  group('GET annual-continuations DTO (T5/T6)', () {
    test('parses a returned CQ user without prior GM row', () {
      final item = AnnualContinuationModel.fromJson({
        'user_id': 'user-returned-from-cq-uuid',
        'name': 'Luis Pérez Soto',
        'base_section_id': 301,
        'ecclesiastical_year_id': 2026,
        'annual_status': 'not_enrolled',
        'current_role': null,
        'eligibility': 'eligible',
        'blocked_reason': null,
        'suggested_class': {'status': 'resolved', 'class_id': 42},
      });

      expect(item.userId, 'user-returned-from-cq-uuid');
      expect(item.name, 'Luis Pérez Soto');
      expect(item.baseSectionId, 301);
      expect(item.ecclesiasticalYearId, 2026);
      expect(item.annualStatus, 'not_enrolled');
      expect(item.eligibility, 'eligible');
      expect(item.blockedReason, isNull);
      expect(item.suggestedClass.status, 'resolved');
      expect(item.suggestedClass.classId, 42);
      expect(item.isBlocked, isFalse);
    });

    test('does not treat already_continued / last_role as the list contract', () {
      final item = AnnualContinuationModel.fromJson({
        'user_id': 'user-a',
        'name': 'Ana',
        'base_section_id': 301,
        'ecclesiastical_year_id': 2026,
        'annual_status': 'not_enrolled',
        'eligibility': 'eligible',
        'already_continued': true,
        'last_role': 'director',
      });

      expect(item.annualStatus, 'not_enrolled');
      expect(item.currentRole, isNull);
    });

    test('unwraps nested paginated envelope data.data', () {
      final items = unwrapAnnualContinuationItems({
        'status': 'success',
        'data': {
          'data': [
            {
              'user_id': 'user-returned-from-cq-uuid',
              'name': 'Luis Pérez Soto',
              'base_section_id': 301,
              'ecclesiastical_year_id': 2026,
              'annual_status': 'not_enrolled',
              'eligibility': 'eligible',
              'suggested_class': {
                'status': 'blocked',
                'code': 'ANNUAL_CLASS_POLICY_UNRESOLVED',
              },
            },
          ],
          'meta': {'total': 1, 'page': 1, 'limit': 20},
        },
      });

      expect(items, hasLength(1));
      expect(items.first.suggestedClass.status, 'blocked');
      expect(
        items.first.suggestedClass.code,
        'ANNUAL_CLASS_POLICY_UNRESOLVED',
      );
    });
  });

  group('POST annual-continuations outcomes', () {
    test('maps enrolled, already_enrolled, blocked and failed per user', () {
      final batch = ContinuationBatchResult.fromJson({
        'results': [
          {
            'user_id': 'enrolled-user',
            'outcome': 'enrolled',
            'club_section_id': 301,
            'ecclesiastical_year_id': 2026,
            'enrollment_id': 99,
            'error_code': null,
          },
          {
            'user_id': 'already-user',
            'outcome': 'already_enrolled',
            'club_section_id': 301,
            'ecclesiastical_year_id': 2026,
            'enrollment_id': null,
            'error_code': null,
          },
          {
            'user_id': 'blocked-user',
            'outcome': 'blocked',
            'club_section_id': 301,
            'ecclesiastical_year_id': 2026,
            'enrollment_id': null,
            'error_code': 'ANNUAL_CLASS_POLICY_UNRESOLVED',
          },
          {
            'user_id': 'failed-user',
            'outcome': 'failed',
            'club_section_id': 301,
            'ecclesiastical_year_id': 2026,
            'enrollment_id': null,
            'error_code': 'INTERNAL_SERVER_ERROR',
          },
        ],
      });

      expect(batch.enrolledCount, 1);
      expect(batch.alreadyEnrolledCount, 1);
      expect(batch.blockedCount, 1);
      expect(batch.failedCount, 1);
      expect(batch.hasPartialFailure, isTrue);
      expect(batch.results[2].errorCode, 'ANNUAL_CLASS_POLICY_UNRESOLVED');
      expect(batch.results[0].enrollmentId, 99);
    });
  });

  group('auth: future director vs operational appointment', () {
    test('designated director is not a selectable club context', () {
      const designated = AuthorizationGrant(
        assignmentId: 'future-director',
        roleName: 'director',
        status: 'designated',
        sectionId: 301,
      );

      expect(selectableClubAssignments([designated]), isEmpty);
      expect(visibleClubAssignments([designated]), isEmpty);
    });

    test('operational GM director wins over not-enrolled banner of another section',
        () {
      const snap = AuthorizationSnapshot(
        activeAssignmentId: 'inactive-cq',
        clubAssignments: [
          AuthorizationGrant(
            assignmentId: 'inactive-cq',
            roleName: 'member',
            status: 'inactive',
            clubId: 500,
            sectionId: 101,
            clubName: 'Club Norte',
          ),
          AuthorizationGrant(
            assignmentId: 'gm-director',
            roleName: 'director',
            status: 'active',
            clubId: 500,
            sectionId: 301,
            clubName: 'Club Norte',
          ),
        ],
      );

      expect(membershipGrantForDisplay(snap), isNull);
      expect(
        selectableClubAssignments(snap.clubAssignments)
            .map((g) => g.assignmentId),
        ['gm-director'],
      );
    });

    test('inactive-only membership still surfaces not-enrolled grant', () {
      const snap = AuthorizationSnapshot(
        activeAssignmentId: 'ghost-1',
        clubAssignments: [
          AuthorizationGrant(
            assignmentId: 'ghost-1',
            roleName: 'member',
            status: 'inactive',
            clubId: 500,
            sectionId: 301,
            clubName: 'Club Norte',
          ),
        ],
      );

      final grant = membershipGrantForDisplay(snap);
      expect(grant, isNotNull);
      expect(grant!.isInactive, isTrue);
    });
  });
}
