import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/auth/data/models/user_model.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/family/data/models/dependent_models.dart';
import 'package:sacdia_app/features/family/domain/entities/supervised_login.dart';
import 'package:sacdia_app/features/legal/data/models/legal_status_model.dart';
import 'package:sacdia_app/features/teen/data/models/teen_models.dart';

/// Payloads EXACTOS confirmados por el QA de la API real (Fase 3a). Si el
/// backend cambia una forma, estos tests deben fallar antes que la pantalla.

const _legalBlock = {
  'requires_acceptance': true,
  'documents': [
    {
      'document_type': 'terms',
      'version': '2026-10-01',
      'url': 'https://sacdia.example/legal/terms',
      'accepted': false,
      'accepted_at': null,
    },
    {
      'document_type': 'privacy',
      'version': '2026-09-01',
      'url': 'https://sacdia.example/legal/privacy',
      'accepted': true,
      'accepted_at': '2026-09-02T12:00:00.000Z',
    },
  ],
};

Map<String, dynamic> _adultMe() => {
      'user_id': 'adult-1',
      'email': 'adult@example.com',
      'name': 'Luis',
      'mode': 'adult',
      'analytics_anonymous': false,
      'principal': {'kind': 'user', 'scopes': null, 'supervision': null},
      'family': {'is_guardian': true, 'dependents_count': 2},
      'family_features': {
        'teen_login': true,
        'linked_device': false,
        'director_create_minor': true,
      },
      'legal': _legalBlock,
    };

Map<String, dynamic> _teenMe({
  required String mode,
  required Map<String, dynamic> supervision,
}) =>
    {
      'user_id': 'teen-1',
      'email': null,
      'name': 'Ana',
      'mode': mode,
      'analytics_anonymous': true,
      'principal': {
        'kind': 'supervised_user',
        'scopes': ['self:read', 'profile:write'],
        'supervision': supervision,
      },
      // Un adolescente no tiene bloque de familia.
      'family': null,
      'family_features': {
        'teen_login': true,
        'linked_device': false,
        'director_create_minor': false,
      },
      'legal': {'requires_acceptance': false, 'documents': <Object>[]},
    };

void main() {
  group('/auth/me', () {
    test('adult: mode, analytics, principal, family, features and legal', () {
      final user = UserModel.fromCustomApi(_adultMe());

      expect(user.serverMode, AccountMode.adult);
      expect(user.mode, AccountMode.adult);
      expect(user.analyticsAnonymous, isFalse);
      expect(user.canIdentifyInAnalytics, isTrue);
      expect(user.principal!.kind, PrincipalKind.user);
      expect(user.principal!.scopes, isNull);
      expect(user.principal!.supervision, isNull);
      expect(user.family!.isGuardian, isTrue);
      expect(user.family!.dependentsCount, 2);
      expect(user.familyFeatures!.teenLogin, isTrue);
      expect(user.familyFeatures!.linkedDevice, isFalse);
      expect(user.familyFeatures!.directorCreateMinor, isTrue);
      expect(user.legalAcceptancePending, isTrue);
    });

    test('data.legal.documents parse with the exact keys', () {
      final status = LegalStatusModel.fromJson(
        Map<String, dynamic>.from(_legalBlock),
      ).toEntity();

      expect(status.requiresAcceptance, isTrue);
      expect(status.documents, hasLength(2));
      expect(status.documents[0].documentType, 'terms');
      expect(status.documents[0].version, '2026-10-01');
      expect(status.documents[0].url, 'https://sacdia.example/legal/terms');
      expect(status.documents[0].accepted, isFalse);
      expect(status.documents[0].acceptedAt, isNull);
      expect(status.documents[1].accepted, isTrue);
      expect(status.documents[1].acceptedAt, DateTime.utc(2026, 9, 2, 12));
    });

    test('teen_pending: a pending guardian stops the clock (nulls)', () {
      final user = UserModel.fromCustomApi(_teenMe(
        mode: 'teen_pending',
        supervision: {
          'status': 'pending_guardian',
          'pending_since': null,
          'guardians': [
            {
              'guardianship_id': 'gs-1',
              'consent_status': 'pending',
              'display_name': 'María Pérez',
              'relationship_type_name': 'Madre',
            },
          ],
          'summary_visible_to_guardians': true,
          'days_left': null,
        },
      ));

      expect(user.mode, AccountMode.teenPending);
      expect(user.family, isNull);
      expect(user.analyticsAnonymous, isTrue);
      expect(user.canIdentifyInAnalytics, isFalse);
      final s = user.principal!.supervision!;
      expect(s.status, SupervisionStatus.pendingGuardian);
      expect(s.pendingSince, isNull);
      expect(s.serverDaysLeft, isNull);
      expect(s.daysLeftAt(DateTime.utc(2026, 10, 19)), isNull);
      expect(s.summaryVisibleToGuardians, isTrue);
      final g = s.guardians.single;
      expect(g.guardianshipId, 'gs-1');
      expect(g.consentStatus, 'pending');
      expect(g.displayName, 'María Pérez');
      expect(g.relationshipTypeName, 'Madre');
    });

    test('teen_pending without a guardian: server days_left drives the clock',
        () {
      final user = UserModel.fromCustomApi(_teenMe(
        mode: 'teen_pending',
        supervision: {
          'status': 'pending_guardian',
          'pending_since': '2026-10-01T00:00:00.000Z',
          'guardians': <Object>[],
          'summary_visible_to_guardians': true,
          'days_left': 72,
        },
      ));

      final s = user.principal!.supervision!;
      expect(s.guardians, isEmpty);
      expect(s.pendingSince, DateTime.utc(2026, 10, 1));
      expect(s.daysLeftAt(DateTime.utc(2026, 10, 19)), 72);
    });

    test('teen_supervised: verified guardian, no clock, no family block', () {
      final user = UserModel.fromCustomApi(_teenMe(
        mode: 'teen_supervised',
        supervision: {
          'status': 'active',
          'pending_since': null,
          'guardians': [
            {
              'guardianship_id': 'gs-2',
              'consent_status': 'verified',
              'display_name': 'Luis Gómez',
              'relationship_type_name': 'Padre',
            },
          ],
          'summary_visible_to_guardians': true,
          'days_left': null,
        },
      ));

      expect(user.mode, AccountMode.teenSupervised);
      expect(user.isSupervisedTeen, isTrue);
      expect(user.family, isNull);
      expect(user.principal!.scopes, ['self:read', 'profile:write']);
      final s = user.principal!.supervision!;
      expect(s.status, SupervisionStatus.active);
      expect(s.isPending, isFalse);
      expect(s.daysLeftAt(DateTime.utc(2026, 10, 19)), isNull);
      expect(s.guardians.single.consentStatus, 'verified');
    });

    test('login data.user.principal: {kind, supervision} in both forms', () {
      final pending = UserModel.fromCustomApi({
        'id': 'teen-1',
        'name': 'Ana',
        'email': null,
        'principal': {
          'kind': 'supervised_user',
          'supervision': 'pending_guardian',
        },
      });
      expect(pending.principal!.kind, PrincipalKind.supervisedUser);
      expect(pending.principal!.supervision!.isPending, isTrue);
      expect(pending.mode, AccountMode.teenPending);

      final adult = UserModel.fromCustomApi({
        'id': 'adult-1',
        'email': 'adult@example.com',
        'principal': {'kind': 'user', 'supervision': null},
      });
      expect(adult.principal!.kind, PrincipalKind.user);
      expect(adult.principal!.supervision, isNull);
      expect(adult.mode, AccountMode.adult);
    });
  });

  group('GET /users/me/supervision', () {
    test('adds open_link_code (expiry only) next to the /auth/me fields', () {
      final s = TeenJson.supervision({
        'status': 'pending_guardian',
        'pending_since': '2026-10-01T00:00:00.000Z',
        'guardians': [
          {
            'guardianship_id': 'gs-1',
            'consent_status': 'pending',
            'display_name': 'María Pérez',
            'relationship_type_name': 'Madre',
          },
        ],
        'open_link_code': {'expires_at': '2026-10-22T10:00:00.000Z'},
        'summary_visible_to_guardians': true,
        'days_left': 72,
      });

      expect(s.openLinkCode!.expiresAt, DateTime.utc(2026, 10, 22, 10));
      expect(s.guardians.single.guardianshipId, 'gs-1');
      expect(s.guardians.single.verified, isFalse);
      expect(s.daysLeftAt(DateTime.utc(2026, 10, 19)), 72);
    });

    test('open_link_code: null means there is no open code', () {
      final s = TeenJson.supervision({
        'status': 'active',
        'pending_since': null,
        'guardians': <Object>[],
        'open_link_code': null,
        'summary_visible_to_guardians': true,
        'days_left': null,
      });
      expect(s.openLinkCode, isNull);
    });

    test('an adult gets status null and nothing else', () {
      final s = TeenJson.supervision({
        'status': null,
        'pending_since': null,
        'guardians': <Object>[],
        'open_link_code': null,
        'summary_visible_to_guardians': true,
        'days_left': null,
      });
      expect(s.status, isNull);
      expect(s.guardians, isEmpty);
    });

    test('only a PENDING guardian can be revoked by the teen', () {
      bool canRemove(Object? consent) {
        final s = TeenJson.supervision({
          'status': 'active',
          'guardians': [
            {
              'guardianship_id': 'gs-1',
              'display_name': 'X',
              if (consent != null) 'consent_status': consent,
            },
          ],
        });
        return s.guardians.single.canBeRemovedByTeen;
      }

      expect(canRemove('pending'), isTrue);
      // El servidor responde 403 PRINCIPAL_SCOPE_DENIED a un vínculo verificado.
      expect(canRemove('verified'), isFalse);
      expect(canRemove(null), isFalse);
      expect(canRemove('something_new'), isFalse);
    });
  });

  group('teen link code (201)', () {
    test('code + expires_at', () {
      final c = TeenJson.linkCode({
        'code': '7KQ4-M9TX',
        'expires_at': '2026-10-22T10:00:00.000Z',
      });
      expect(c.code, '7KQ4-M9TX');
      expect(c.expiresAt, DateTime.utc(2026, 10, 22, 10));
    });
  });

  group('enable supervised login (201)', () {
    test('supervised_login block and devices_revoked', () {
      final r = FamilyJson.enabledLogin({
        'supervised_login': {
          'method': 'handle',
          'login_handle': 'ana-7kq4m9',
          'email': null,
          'origin': 'guardian_enabled',
          'enabled_at': '2026-10-19T10:00:00.000Z',
          'disabled_at': null,
          'disabled_reason': null,
          'password_set_by': 'guardian',
        },
        'devices_revoked': 2,
      });

      final login = r.supervisedLogin;
      expect(login.method, SupervisedLoginMethod.handle);
      expect(login.loginHandle, 'ana-7kq4m9');
      expect(login.email, isNull);
      expect(login.origin, 'guardian_enabled');
      expect(login.enabledAt, DateTime.utc(2026, 10, 19, 10));
      expect(login.disabledAt, isNull);
      expect(login.disabledReason, isNull);
      expect(login.passwordSetBy, PasswordSetBy.guardian);
      expect(login.isDisabled, isFalse);
      expect(r.devicesRevoked, 2);
    });
  });

  group('guardian summary', () {
    test('exact payload: dependent, classes, honors, attendance, dues null',
        () {
      final s = FamilyJson.progressSummary({
        'dependent': {
          'user_id': 'ana-1',
          'name': 'Ana Pérez',
          'age': 14,
          'access_mode': 'supervised_login',
        },
        'classes': [
          {
            'class_id': 7,
            'name': 'Amigo',
            'status': 'in_progress',
            'progress_percent': 40,
            'sections_completed': 4,
            'sections_total': 10,
          },
        ],
        'honors': {'completed': 3, 'in_progress': 1},
        'attendance': {
          'from': '2026-01-01',
          'to': '2026-12-31',
          'activities_total': 20,
          'activities_attended': 15,
          'last_attended_on': '2026-10-12',
        },
        'dues': null,
        'generated_at': '2026-10-19T10:00:00.000Z',
      });

      expect(s.userId, 'ana-1');
      expect(s.name, 'Ana Pérez');
      expect(s.age, 14);
      expect(s.supervisedLogin, isTrue);
      final c = s.classes.single;
      expect(c.classId, 7);
      expect(c.name, 'Amigo');
      expect(c.progressPercent, 40);
      expect(c.sectionsCompleted, 4);
      expect(c.sectionsTotal, 10);
      expect(s.honorsCompleted, 3);
      expect(s.honorsInProgress, 1);
      expect(s.attendance.from, DateTime(2026, 1, 1));
      expect(s.attendance.to, DateTime(2026, 12, 31));
      expect(s.attendance.activitiesTotal, 20);
      expect(s.attendance.activitiesAttended, 15);
      expect(s.attendance.percent, 75);
      expect(s.attendance.lastAttendedOn, DateTime(2026, 10, 12));
      expect(s.generatedAt, DateTime.utc(2026, 10, 19, 10));
    });

    test('a teen who never attended has no last_attended_on', () {
      final s = FamilyJson.progressSummary({
        'dependent': {
          'user_id': 'ana-1',
          'name': 'Ana',
          'age': 14,
          'access_mode': 'guardian_managed',
        },
        'classes': <Object>[],
        'honors': {'completed': 0, 'in_progress': 0},
        'attendance': {
          'from': '2026-01-01',
          'to': '2026-12-31',
          'activities_total': 0,
          'activities_attended': 0,
          'last_attended_on': null,
        },
        'dues': null,
        'generated_at': '2026-10-19T10:00:00.000Z',
      });

      expect(s.supervisedLogin, isFalse);
      expect(s.attendance.lastAttendedOn, isNull);
      expect(s.attendance.percent, 0);
    });
  });
}
