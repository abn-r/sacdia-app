import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/supervision/data/models/supervision_club_model.dart';

Map<String, dynamic> _item({Object? id = 5}) => {
      'club_id': id,
      'name': '  Club Orion ',
      'description': null,
      'active': true,
      'local_field_id': 3,
      'address': null,
      'church_id': 9,
      'churches': {'name': 'Iglesia Central'},
      'districts': {'name': 'Distrito 1'},
      'local_fields': {'name': 'Campo Norte'},
      'club_sections': [
        {
          'club_section_id': 1,
          'active': true,
          'club_type_id': 2,
          'club_types': {'club_type_id': 2, 'name': 'Conquistadores'},
        },
        {
          'club_section_id': 2,
          'active': false,
          'club_type_id': 1,
          'club_types': {'club_type_id': 1, 'name': 'Aventureros'},
        },
        {
          'club_section_id': 3,
          'active': true,
          'club_type_id': 2,
          'club_types': {'club_type_id': 2, 'name': 'Conquistadores'},
        },
        {
          'club_section_id': 4,
          'active': true,
          'club_type_id': 3,
          'club_types': {'club_type_id': 3, 'name': '  '},
        },
      ],
    };

void main() {
  group('list', () {
    test('parses an item; activeSectionNames skips inactive/blank/dupes', () {
      final item = SupervisionClubModel.tryParseListItem(_item())!;
      expect(item.id, 5);
      expect(item.name, 'Club Orion');
      expect(item.active, isTrue);
      expect(item.churchName, 'Iglesia Central');
      expect(item.districtName, 'Distrito 1');
      expect(item.localFieldName, 'Campo Norte');
      expect(item.sections, hasLength(4));
      expect(item.activeSectionNames, ['Conquistadores']);
    });

    test('sections are ordered by club type, ties in server order', () {
      Map<String, dynamic> section(int id, int type, String name) => {
            'club_section_id': id,
            'active': true,
            'club_type_id': type,
            'club_types': {'club_type_id': type, 'name': name},
          };
      final item = SupervisionClubModel.tryParseListItem({
        ..._item(),
        'club_sections': [
          section(9, 3, 'Guías Mayores'),
          section(8, 1, 'Aventureros'),
          section(7, 2, 'Conquistadores'),
          section(6, 1, 'Aventureros'),
        ],
      })!;

      expect(item.sections.map((s) => s.id), [8, 6, 7, 9]);
      expect(
        item.activeSectionNames,
        ['Aventureros', 'Conquistadores', 'Guías Mayores'],
      );
    });

    test('item without id is dropped; wrong types do not throw', () {
      expect(SupervisionClubModel.tryParseListItem(_item(id: null)), isNull);
      expect(SupervisionClubModel.tryParseListItem('x'), isNull);
      final item = SupervisionClubModel.tryParseListItem({
        'club_id': '7',
        'name': 5,
        'active': 'true',
        'churches': 'x',
        'club_sections': 'x',
      })!;
      expect(item.id, 7);
      expect(item.active, isTrue);
      expect(item.churchName, '');
      expect(item.sections, isEmpty);
    });

    test('page reads meta.hasNextPage', () {
      final page = SupervisionClubModel.parsePage({
        'data': [_item(), _item(id: 6), 'junk'],
        'meta': {
          'page': 2,
          'limit': 25,
          'total': 60,
          'totalPages': 3,
          'hasNextPage': true,
          'hasPreviousPage': true,
        },
      });
      expect(page.items.map((e) => e.id), [5, 6]);
      expect(page.page, 2);
      expect(page.total, 60);
      expect(page.hasMore, isTrue);
      final last = SupervisionClubModel.parsePage({
        'data': [_item()],
        'meta': {'page': 3, 'total': 51, 'hasNextPage': false},
      });
      expect(last.hasMore, isFalse);
    });

    test('empty / garbage page', () {
      final page = SupervisionClubModel.parsePage(null);
      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
    });
  });

  group('profile', () {
    final raw = {
      ..._item(),
      'description': ' Un club ',
      'address': 'Calle 1',
      'local_fields': {
        'local_field_id': 3,
        'name': 'Campo Norte',
        'union_id': 1,
      },
      'club_sections': [
        {
          'club_section_id': 1,
          'active': true,
          'souls_target': '12',
          'club_type_id': 2,
          'phone': ' 555 ',
          'email': '',
          'club_types': {'club_type_id': 2, 'name': 'Conquistadores'},
        },
      ],
    };

    test('bare object', () {
      final p = SupervisionClubModel.tryParseProfile(raw)!;
      expect(p.id, 5);
      expect(p.description, 'Un club');
      expect(p.address, 'Calle 1');
      expect(p.localFieldName, 'Campo Norte');
      expect(p.sections.single.soulsTarget, 12);
      expect(p.sections.single.phone, '555');
      expect(p.sections.single.email, isNull);
      expect(p.sections.single.typeName, 'Conquistadores');
    });

    test('enveloped equals bare', () {
      expect(SupervisionClubModel.tryParseProfile({'data': raw}),
          SupervisionClubModel.tryParseProfile(raw));
    });

    test('null without id', () {
      expect(SupervisionClubModel.tryParseProfile({'name': 'x'}), isNull);
      expect(SupervisionClubModel.tryParseProfile(null), isNull);
    });
  });

  group('overview', () {
    test('parses funnel, events and ignores score', () {
      final o = SupervisionClubModel.parseOverview({
        'status': 'ok',
        'data': {
          'attendance': [
            {'year': 2026, 'week': 1, 'avg_pct': 80}
          ],
          'attendance_average': 81.5,
          'score': {'total': 99},
          'upcoming_events': [
            {
              'activity_id': 1,
              'name': 'Campamento',
              'kind': 'camp',
              'activity_date': '2026-12-05',
              'section_name': 'Conquistadores',
            },
            {'activity_id': 2, 'name': 'Sin fecha', 'activity_date': null},
            {'name': 'sin id'},
          ],
          'funnel': {
            'pending_requests': 2,
            'active_members': '40',
            'investidos_year': 7,
          },
        },
      });
      expect(o.attendanceAverage, 81.5);
      expect(o.activeMembers, 40);
      expect(o.investedThisYear, 7);
      expect(o.pendingRequests, 2);
      expect(o.upcomingEvents, hasLength(2));
      // Date-only parses to local midnight, no timezone shift.
      expect(o.upcomingEvents.first.date, DateTime(2026, 12, 5));
      expect(o.upcomingEvents.first.date!.isUtc, isFalse);
      expect(o.upcomingEvents.first.sectionName, 'Conquistadores');
      expect(o.upcomingEvents.last.date, isNull);
      expect(o.upcomingEvents.last.sectionName, isNull);
    });

    test('nulls give zeros', () {
      final o = SupervisionClubModel.parseOverview({
        'data': {'attendance': null, 'attendance_average': null},
      });
      expect(o.attendanceAverage, isNull);
      expect(o.activeMembers, 0);
      expect(o.upcomingEvents, isEmpty);
    });
  });

  group('leadership', () {
    Map<String, dynamic> person(
            String id, String? name, String? p, String? m, String role) =>
        {
          'assignment_id': 1,
          'user_id': id,
          'name': name,
          'paternal_last_name': p,
          'maternal_last_name': m,
          'role_name': role,
          'section_name': null,
        };

    test('composes the full name; ignores others', () {
      final l = SupervisionClubModel.parseLeadership({
        'status': 'ok',
        'data': {
          'director': person('u1', ' Ana ', 'Perez', null, 'Director'),
          'deputies': [person('u2', 'Luis', ' ', 'Gomez', 'Subdirector')],
          'secretaries': [
            {
              ...person('u3', 'Eva', 'Ruiz', 'Diaz', 'Secretaria'),
              'section_name': 'Aventureros'
            },
          ],
          'others': [person('u4', 'Otro', 'X', 'Y', 'Tesorero')],
        },
      });
      expect(l.director!.fullName, 'Ana Perez');
      expect(l.director!.roleName, 'Director');
      expect(l.deputies.single.fullName, 'Luis Gomez');
      expect(l.secretaries.single.fullName, 'Eva Ruiz Diaz');
      expect(l.secretaries.single.sectionName, 'Aventureros');
      expect(l.isEmpty, isFalse);
    });

    test('null director and empty lists', () {
      final l = SupervisionClubModel.parseLeadership({
        'data': {'director': null, 'deputies': [], 'secretaries': []},
      });
      expect(l.director, isNull);
      expect(l.isEmpty, isTrue);
      expect(SupervisionClubModel.parseLeadership(null).isEmpty, isTrue);
    });

    test('person with no name still keeps the user id', () {
      final l = SupervisionClubModel.parseLeadership({
        'data': {
          'director': person('u9', null, null, null, 'Director'),
        },
      });
      expect(l.director!.userId, 'u9');
      expect(l.director!.fullName, '');
    });
  });
}
