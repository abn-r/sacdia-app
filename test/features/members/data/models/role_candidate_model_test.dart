import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/members/data/models/role_candidate_model.dart';
import 'package:sacdia_app/features/members/domain/entities/role_candidate.dart';

Map<String, dynamic> _item() => {
      'user_id': 'uuid-1',
      'name': 'Laura Méndez',
      'photo_url': 'https://cdn.example.com/laura.jpg',
      'age': 34,
      'group': 'with_role',
      'gm_annual_status': 'active',
      'guide_major': {
        'basis': 'INVESTED',
        'investiture_year': '2019',
        'advanced': true,
        'instructor': false,
      },
      'current_roles': [
        {
          'section_id': 165,
          'club_type_id': 2,
          'club_type_name': 'Conquistadores',
          'role': 'counselor',
        },
      ],
      'service_years': 6,
      'consent': {'required': true, 'verified': false},
      'allowed_roles': ['deputy-director', 'treasurer'],
      'blocked_reason': null,
    };

Map<String, dynamic> _body() => {
      'status': 'success',
      'data': {
        'section': {
          'id': 163,
          'club_type_id': 1,
          'club_type_name': 'Aventureros',
          'year': {'id': 4, 'name': '2026'},
        },
        'slots': [
          {
            'role': 'deputy-director',
            'occupied': 1,
            'max': 2,
            'holders': ['Ana Ruiz'],
            'blocked_by': [],
          },
          {
            'role': 'secretary-treasurer',
            'occupied': 0,
            'max': 1,
            'holders': [],
            'blocked_by': ['secretary'],
          },
          {
            'role': 'counselor',
            'occupied': 3,
            'max': null,
            'holders': ['Pedro'],
            'blocked_by': [],
          },
        ],
        'items': [_item()],
      },
      'meta': {
        'page': 1,
        'limit': 20,
        'total': 7,
        'counts': {'available': 4, 'with_role': 3, 'not_enrolled': 0},
      },
    };

void main() {
  group('RoleCandidatesPageModel.fromJson', () {
    test('parses the full contract', () {
      final page = RoleCandidatesPageModel.fromJson(_body());

      expect(page.section?.id, 163);
      expect(page.section?.clubTypeName, 'Aventureros');
      expect(page.section?.yearName, '2026');
      expect(page.page, 1);
      expect(page.limit, 20);
      expect(page.total, 7);
      expect(page.counts.available, 4);
      expect(page.counts.withRole, 3);
      expect(page.counts.notEnrolled, 0);

      final deputy = page.slotFor('deputy-director')!;
      expect(deputy.occupied, 1);
      expect(deputy.max, 2);
      expect(deputy.holders, ['Ana Ruiz']);
      expect(deputy.isFull, isFalse);
      expect(page.slotFor('secretary-treasurer')!.blockedBy, ['secretary']);
      final counselor = page.slotFor('counselor')!;
      expect(counselor.max, isNull);
      expect(counselor.isUnbounded, isTrue);
      expect(counselor.isFull, isFalse);

      final item = page.items.single;
      expect(item.userId, 'uuid-1');
      expect(item.photoUrl, 'https://cdn.example.com/laura.jpg');
      expect(item.group, RoleCandidateGroup.withRole);
      expect(item.gmAnnualStatus, GmAnnualStatus.active);
      expect(item.guideMajor?.basis, GuideMajorBasis.invested);
      expect(item.guideMajor?.investitureYear, '2019');
      expect(item.guideMajor?.advanced, isTrue);
      expect(item.guideMajor?.instructor, isFalse);
      expect(item.currentRoles.single.sectionId, 165);
      expect(item.currentRoles.single.clubTypeName, 'Conquistadores');
      expect(item.serviceYears, 6);
      expect(item.consent?.required, isTrue);
      expect(item.consent?.verified, isFalse);
      expect(item.isConsentMissing, isTrue);
      expect(item.allowedRoles, ['deputy-director', 'treasurer']);
      expect(item.blockedReason, isNull);
    });

    test('tolerates nulls and missing optional fields', () {
      final page = RoleCandidatesPageModel.fromJson({
        'data': {
          'section': null,
          'slots': null,
          'items': [
            {
              'user_id': 'u2',
              'name': 'Sin datos',
              'photo_url': null,
              'age': null,
              'group': 'available',
              'gm_annual_status': 'none',
              'guide_major': {
                'basis': 'APPROVED',
                'investiture_year': null,
                'advanced': false,
                'instructor': false,
              },
              'current_roles': [],
              'service_years': null,
              'consent': null,
              'allowed_roles': [],
              'blocked_reason': 'CLUB_ROLE_GM_MEMBERSHIP_REQUIRED',
            },
            {'user_id': 'u3', 'name': 'Mínimo', 'group': 'weird'},
          ],
        },
        'meta': {'page': 1, 'limit': 20},
      });

      expect(page.section, isNull);
      expect(page.slots, isEmpty);
      expect(page.total, 2, reason: 'falls back to the items received');
      expect(page.counts.available, 0);

      final first = page.items.first;
      expect(first.photoUrl, isNull);
      expect(first.age, isNull);
      expect(first.serviceYears, isNull);
      expect(first.consent, isNull);
      expect(first.isConsentMissing, isFalse);
      expect(first.guideMajor?.basis, GuideMajorBasis.approved);
      expect(first.guideMajor?.investitureYear, isNull);
      expect(
          first.blockedReason, RoleCandidateBlockedReason.gmMembershipRequired);

      final minimal = page.items.last;
      expect(minimal.group, RoleCandidateGroup.notEnrolled,
          reason: 'an unknown group fails closed (no action)');
      expect(minimal.guideMajor, isNull);
      expect(minimal.allowedRoles, isEmpty);
      expect(minimal.currentRoles, isEmpty);
    });

    test('an unknown basis does not break parsing', () {
      final page = RoleCandidatesPageModel.fromJson({
        'data': {
          'items': [
            {
              'user_id': 'u',
              'name': 'N',
              'group': 'available',
              'guide_major': {'basis': 'SOMETHING_NEW'},
            },
          ],
        },
      });
      expect(page.items.single.guideMajor?.basis, GuideMajorBasis.unknown);
    });
  });

  group('RoleCandidate.isActionable', () {
    const base = RoleCandidate(
      userId: 'u',
      name: 'N',
      group: RoleCandidateGroup.available,
      allowedRoles: ['counselor'],
    );

    test('needs allowed roles', () {
      expect(base.isActionable(163), isTrue);
      expect(
        const RoleCandidate(
          userId: 'u',
          name: 'N',
          group: RoleCandidateGroup.available,
        ).isActionable(163),
        isFalse,
      );
    });

    test('is not actionable for a minor without verified consent', () {
      const minor = RoleCandidate(
        userId: 'u',
        name: 'N',
        group: RoleCandidateGroup.available,
        allowedRoles: ['counselor'],
        consent: RoleCandidateConsent(required: true, verified: false),
      );
      expect(minor.isActionable(163), isFalse);
    });

    test('is not actionable when the role is in THIS section', () {
      const held = RoleCandidate(
        userId: 'u',
        name: 'N',
        group: RoleCandidateGroup.withRole,
        allowedRoles: ['counselor'],
        currentRoles: [
          RoleCandidateCurrentRole(sectionId: 163, role: 'secretary'),
        ],
      );
      expect(held.isActionable(163), isFalse);
      expect(held.isActionable(999), isTrue);
    });
  });

  group('RoleCandidateDetailModel.fromJson', () {
    test('parses history, certifications, insurance and honors', () {
      final detail = RoleCandidateDetailModel.fromJson({
        'status': 'success',
        'data': {
          ..._item(),
          'role_history': [
            {
              'year_name': '2025',
              'club_type_name': 'Conquistadores',
              'role': 'counselor',
            },
          ],
          'certifications': [
            {
              'name': 'Primeros auxilios',
              'status': 'approved',
              'certified_at': '2025-03-10T00:00:00.000Z',
            },
            {'name': 'Sin fecha', 'status': null, 'certified_at': null},
          ],
          'insurance': {'active': true, 'expires_at': '2026-12-31'},
          'honors_count': 12,
        },
      });

      expect(detail.candidate.userId, 'uuid-1');
      expect(detail.roleHistory.single.yearName, '2025');
      expect(detail.roleHistory.single.role, 'counselor');
      expect(detail.certifications, hasLength(2));
      expect(detail.certifications.first.certifiedAt?.year, 2025);
      expect(detail.certifications.last.certifiedAt, isNull);
      expect(detail.insurance?.active, isTrue);
      expect(detail.insurance?.expiresAt?.month, 12);
      expect(detail.honorsCount, 12);
    });

    test('null insurance and missing lists', () {
      final detail = RoleCandidateDetailModel.fromJson({
        'data': {'user_id': 'u', 'name': 'N', 'group': 'available'},
      });
      expect(detail.insurance, isNull);
      expect(detail.roleHistory, isEmpty);
      expect(detail.certifications, isEmpty);
      expect(detail.honorsCount, 0);
    });
  });

  group('requirements and credentials', () {
    test('a missing or empty requirements list means no requirements', () {
      expect(RoleCandidateModel.fromJson(_item()).requirements, isEmpty);
      expect(
        RoleCandidateModel.fromJson({..._item(), 'requirements': []})
            .requirements,
        isEmpty,
      );
      expect(
        RoleCandidateModel.fromJson({..._item(), 'requirements': 'x'})
            .requirements,
        isEmpty,
      );
    });

    test('parses mode, status and enforced', () {
      final c = RoleCandidateModel.fromJson({
        ..._item(),
        'requirements': [
          {
            'role': 'counselor',
            'type': 'COUNSELOR_TRAINING',
            'mode': 'BLOCK',
            'status': 'PENDING_REVIEW',
            'enforced': true,
          },
        ],
      });
      final r = c.requirementFor('counselor')!;
      expect(r.mode, RequirementMode.block);
      expect(r.status, RequirementStatus.pendingReview);
      expect(r.enforced, isTrue);
      expect(r.blocksAssignment, isTrue);
      expect(c.requirementFor('secretary'), isNull);
    });

    test('unknown mode is INFO and unknown status is MISSING', () {
      final c = RoleCandidateModel.fromJson({
        ..._item(),
        'requirements': [
          {'role': 'counselor', 'mode': 'PANIC', 'status': '???'},
          {'role': 'secretary'},
        ],
      });
      for (final r in c.requirements) {
        expect(r.mode, RequirementMode.info);
        expect(r.status, RequirementStatus.missing);
        expect(r.enforced, isFalse);
        expect(r.isFlagged, isFalse, reason: 'INFO never flags');
      }
      expect(c.hasFlaggedRequirement, isFalse);
    });

    test('BLOCK without enforced does not block but flags', () {
      const r = RoleRequirement(
        role: 'counselor',
        mode: RequirementMode.block,
        status: RequirementStatus.missing,
      );
      expect(r.blocksAssignment, isFalse);
      expect(r.isFlagged, isTrue);
      expect(r.severity, 1);
    });

    test('a MET requirement is never flagged', () {
      const r = RoleRequirement(
        role: 'counselor',
        mode: RequirementMode.block,
        status: RequirementStatus.met,
        enforced: true,
      );
      expect(r.isFlagged, isFalse);
      expect(r.blocksAssignment, isFalse);
    });

    test('detail credentials: parse, tolerate unknowns, pick the best', () {
      final detail = RoleCandidateDetailModel.fromJson({
        ..._item(),
        'credentials': [
          {
            'type': 'COUNSELOR_TRAINING',
            'status': 'WHAT',
            'completed_at': null,
          },
          {
            'type': 'COUNSELOR_TRAINING',
            'status': 'APPROVED',
            'completed_at': '2025-08-01',
            'expires_at': '2027-08-01',
          },
        ],
      });
      expect(detail.credentials, hasLength(2));
      expect(detail.credentials.first.status, CredentialStatus.rejected);
      expect(detail.credentials.first.completedAt, isNull);
      final best = detail.counselorCredential!;
      expect(best.status, CredentialStatus.approved);
      expect(best.completedAt, DateTime(2025, 8, 1));
      expect(best.expiresAt, DateTime(2027, 8, 1));
    });

    test('detail without credentials has none', () {
      final detail = RoleCandidateDetailModel.fromJson(_item());
      expect(detail.credentials, isEmpty);
      expect(detail.counselorCredential, isNull);
      expect(detail.requirementSeverity, isNull);
    });
  });
}
