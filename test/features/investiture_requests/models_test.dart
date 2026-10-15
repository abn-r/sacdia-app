import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/investiture_requests/data/models/investiture_request_model.dart';
import 'package:sacdia_app/features/investiture_requests/data/models/investiture_resolution_model.dart';
import 'package:sacdia_app/features/investiture_requests/data/models/own_investiture_entry_model.dart';
import 'package:sacdia_app/features/investiture_requests/data/models/presentation_context_model.dart';
import 'package:sacdia_app/features/investiture_requests/data/models/yearbook_entry_model.dart';
import 'package:sacdia_app/features/investiture_requests/domain/entities/person_status.dart';

Map<String, dynamic> _personJson({
  String id = 'p1',
  String status = 'PENDING',
  Map<String, dynamic>? extra,
}) =>
    {
      'person_id': id,
      'user_id': 'u1',
      'user_name': 'Ana Pérez',
      'class_id': 3,
      'class_name': 'Amigo',
      'section_name': 'Conquistadores',
      'enrollment_id': 11,
      'investiture_date': '2026-11-15',
      'status': status,
      'can_authorize': true,
      'authorization_comment': null,
      'rejection_reason': null,
      'system_reason': null,
      'resolution_code': null,
      'resolved_by_id': null,
      'resolved_by_name': null,
      'date_changed_by_id': null,
      'date_changed_at': null,
      ...?extra,
    };

void main() {
  group('PresentationContextModel', () {
    test('parses presentation context', () {
      final ctx = PresentationContextModel.fromJson({
        'club_section_id': 4,
        'ecclesiastical_year_id': 9,
        'window': {
          'start_date': '2026-10-01',
          'end_date': '2026-12-20',
          'open_today': true,
          'time_zone_invalid': false,
        },
        'year_open': true,
        'open_request_id': null,
        'candidates': [
          {
            'enrollment_id': 11,
            'user_id': 'u1',
            'user_name': 'Ana',
            'class_id': 3,
            'class_name': 'Amigo',
            'overall_progress': 92,
            'eligible': true,
            'blocked_code': null,
            'pending_person_id': null,
          },
        ],
      });
      expect(ctx.window.openToday, isTrue);
      expect(ctx.window.timeZoneInvalid, isFalse);
      expect(ctx.window.endDate, DateTime(2026, 12, 20));
      expect(ctx.yearOpen, isTrue);
      expect(ctx.openRequestId, isNull);
      expect(ctx.candidates.single.eligible, isTrue);
      expect(ctx.candidates.single.className, 'Amigo');
      expect(ctx.candidates.single.overallProgress, 92);
    });

    test('tolerates null dates, numeric progress as double and blocked code',
        () {
      final ctx = PresentationContextModel.fromJson({
        'club_section_id': 4,
        'ecclesiastical_year_id': 9,
        'window': {
          'start_date': null,
          'end_date': null,
          'open_today': false,
          'time_zone_invalid': true,
        },
        'year_open': false,
        'open_request_id': 'r1',
        'candidates': [
          {
            'enrollment_id': 12,
            'user_id': 'u2',
            'user_name': null,
            'class_id': 3,
            'class_name': null,
            'overall_progress': 45.5,
            'eligible': false,
            'blocked_code': 'INVESTITURE_REQUEST_ALREADY_INVESTED',
            'pending_person_id': 'p9',
          },
        ],
      });
      expect(ctx.window.startDate, isNull);
      expect(ctx.window.timeZoneInvalid, isTrue);
      expect(ctx.openRequestId, 'r1');
      final c = ctx.candidates.single;
      expect(c.overallProgress, 45.5);
      expect(c.blockedCode, 'INVESTITURE_REQUEST_ALREADY_INVESTED');
      expect(c.pendingPersonId, 'p9');
      expect(c.userName, isNull);
    });
  });

  group('PersonStatus', () {
    test('maps person status strings', () {
      expect(PersonStatus.fromString('PENDING'), PersonStatus.pending);
      expect(PersonStatus.fromString('INVESTED'), PersonStatus.invested);
      expect(
        PersonStatus.fromString('REJECTED_BY_PERSON'),
        PersonStatus.rejectedByPerson,
      );
      expect(
        PersonStatus.fromString('REJECTED_BY_SYSTEM'),
        PersonStatus.rejectedBySystem,
      );
      expect(PersonStatus.fromString('REJECTED'), PersonStatus.rejected);
      expect(PersonStatus.fromString('REMOVED'), PersonStatus.removed);
      expect(PersonStatus.fromString('CLOSED_YEAR'), PersonStatus.closedYear);
      expect(PersonStatus.fromString('UNKNOWN'), PersonStatus.unknown);
      expect(PersonStatus.fromString(null), PersonStatus.unknown);
    });
  });

  group('InvestitureRequestModel', () {
    test('parses a request view with header and people', () {
      final req = InvestitureRequestModel.fromJson({
        'request_id': 'r1',
        'club_section_id': 4,
        'ecclesiastical_year_id': 9,
        'club_id': 7,
        'club_name': 'Club Águilas',
        'section_name': 'Conquistadores',
        'district_name': 'Norte',
        'pending_count': 1,
        'earliest_investiture_date': '2026-11-15',
        'created_at': '2026-10-02T10:00:00.000Z',
        'people': [
          _personJson(),
          _personJson(
            id: 'p2',
            status: 'REJECTED_BY_SYSTEM',
            extra: {
              'system_reason': 'Falta de requisitos',
              'can_authorize': false,
            },
          ),
        ],
      });
      expect(req.requestId, 'r1');
      expect(req.clubName, 'Club Águilas');
      expect(req.districtName, 'Norte');
      expect(req.pendingCount, 1);
      expect(req.earliestInvestitureDate, DateTime(2026, 11, 15));
      expect(req.people, hasLength(2));
      final p = req.people.first;
      expect(p.status, PersonStatus.pending);
      expect(p.investitureDate, DateTime(2026, 11, 15));
      expect(p.canAuthorize, isTrue);
      expect(p.sectionName, 'Conquistadores');
      expect(req.people.last.status, PersonStatus.rejectedBySystem);
      expect(req.people.last.systemReason, 'Falta de requisitos');
      expect(req.people.last.canAuthorize, isFalse);
    });

    test('header fields are optional (section view)', () {
      final req = InvestitureRequestModel.fromJson({
        'request_id': 'r1',
        'club_section_id': 4,
        'ecclesiastical_year_id': 9,
        'people': [_personJson()],
      });
      expect(req.clubName, isNull);
      expect(req.pendingCount, isNull);
      expect(req.earliestInvestitureDate, isNull);
    });
  });

  group('InvestitureResolutionModel', () {
    test('parses a resolution view', () {
      final r = InvestitureResolutionModel.fromJson({
        'request_id': 'r1',
        'invested': [_personJson(id: 'p1', status: 'INVESTED')],
        'rejected_by_person': [
          _personJson(id: 'p2', status: 'REJECTED_BY_PERSON'),
        ],
        'rejected_by_system': [
          _personJson(id: 'p3', status: 'REJECTED_BY_SYSTEM'),
        ],
        'retired': [_personJson(id: 'p4', status: 'REMOVED')],
        'blocked': [
          {'person_id': 'p5', 'code': 'INVESTITURE_REQUEST_NOT_PENDING'},
        ],
        'already_resolved': [
          {'person_id': 'p6', 'status': 'INVESTED'},
        ],
      });
      expect(r.requestId, 'r1');
      expect(r.invested.single.status, PersonStatus.invested);
      expect(r.rejectedByPerson.single.personId, 'p2');
      expect(r.rejectedBySystem.single.personId, 'p3');
      expect(r.retired.single.status, PersonStatus.removed);
      expect(r.blocked.single.personId, 'p5');
      expect(r.blocked.single.code, 'INVESTITURE_REQUEST_NOT_PENDING');
      expect(r.alreadyResolved.single.status, PersonStatus.invested);
    });
  });

  group('OwnInvestitureEntryModel', () {
    test('parses a history entry and keeps civil date', () {
      final e = OwnInvestitureEntryModel.fromJson({
        'person_id': 'p1',
        'user_id': 'u1',
        'class_id': 3,
        'class_name': 'Amigo',
        'club_section_id': 4,
        'ecclesiastical_year_id': 9,
        'investiture_date': '2026-11-15',
        'status': 'REJECTED',
        'person_text': null,
        'authorization_comment': 'Felicitaciones',
      });
      expect(e.status, PersonStatus.rejected);
      expect(e.investitureDate, DateTime(2026, 11, 15));
      expect(e.authorizationComment, 'Felicitaciones');
      expect(e.personText, isNull);
      expect(e.rejectionReason, isNull);
    });
  });

  group('YearbookEntryModel', () {
    test('parses a yearbook entry', () {
      final y = YearbookEntryModel.fromJson({
        'enrollment_id': 11,
        'user_id': 'u1',
        'class_id': 3,
        'class_name': 'Amigo',
        'ecclesiastical_year_id': 9,
      });
      expect(y.enrollmentId, 11);
      expect(y.className, 'Amigo');
      expect(y.ecclesiasticalYearId, 9);
    });
  });
}
