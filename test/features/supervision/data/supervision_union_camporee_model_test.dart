import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/supervision/data/models/supervision_union_camporee_model.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_union_camporee.dart';

void main() {
  group('camporee list item / detail', () {
    test('parses fields and keeps calendar dates unshifted', () {
      final c = SupervisionUnionCamporeeModel.tryParse({
        'union_camporee_id': 7,
        'name': 'Camporee Unión',
        'description': ' Desc ',
        'start_date': '2026-08-01T00:00:00.000Z',
        'end_date': '2026-08-03T00:00:00.000Z',
        'union_id': 2,
        'union_camporee_place': 'Rancho Sur',
        'registration_cost': '100.00',
        'orders_enabled': true,
        'orders_opens_at': '2026-07-01T06:00:00.000Z',
        'orders_deadline': '2026-07-20T06:00:00.000Z',
        'active': true,
        'unions': {'union_id': 2, 'name': 'Unión Norte', 'abbreviation': 'UN'},
      })!;
      expect(c.id, 7);
      expect(c.name, 'Camporee Unión');
      expect(c.description, 'Desc');
      expect(c.startDate, DateTime(2026, 8, 1));
      expect(c.endDate, DateTime(2026, 8, 3));
      expect(c.place, 'Rancho Sur');
      expect(c.unionName, 'Unión Norte');
      expect(c.active, isTrue);
      expect(c.ordersEnabled, isTrue);
      expect(c.ordersOpensAt, DateTime.utc(2026, 7, 1, 6));
      expect(c.ordersDeadline, DateTime.utc(2026, 7, 20, 6));
    });

    test('server default "Lugar" and blank place become empty', () {
      for (final p in ['Lugar', '  ', null]) {
        final c = SupervisionUnionCamporeeModel.tryParse(
            {'union_camporee_id': 1, 'union_camporee_place': p})!;
        expect(c.place, '');
      }
    });

    test('tolerates missing, null and wrong-typed fields', () {
      final c = SupervisionUnionCamporeeModel.tryParse({
        'union_camporee_id': '9',
        'name': 5,
        'description': '',
        'start_date': 'nope',
        'end_date': 12,
        'orders_enabled': 'x',
        'orders_deadline': null,
        'unions': 'bad',
      })!;
      expect(c.id, 9);
      expect(c.description, isNull);
      expect(c.startDate, isNull);
      expect(c.endDate, isNull);
      expect(c.ordersEnabled, isFalse);
      expect(c.ordersDeadline, isNull);
      expect(c.unionName, '');
      expect(c.active, isTrue);
    });

    test('rows without id are dropped; list reads the data envelope', () {
      final list = SupervisionUnionCamporeeModel.parseList({
        'data': [
          {'union_camporee_id': 1},
          {'name': 'no id'},
          'junk',
        ],
        'meta': {'page': 1},
      });
      expect(list.map((e) => e.id), [1]);
      expect(SupervisionUnionCamporeeModel.parseList(null), isEmpty);
      expect(SupervisionUnionCamporeeModel.tryParse(null), isNull);
    });
  });

  group('pending payload', () {
    final payload = {
      'clubs': [
        {
          'camporee_club_id': 3,
          'club_id': 8,
          'created_at': '2026-05-01T10:00:00Z'
        },
        {'club_id': 9},
      ],
      'members': [
        {
          'camporee_member_id': '5',
          'club_name': 'Orión',
          'insurance_verified': true,
          'created_at': '2026-05-02T10:00:00Z',
          'users': {
            'name': 'Ana',
            'paternal_last_name': 'Pérez',
            'maternal_last_name': '  ',
          },
        },
        {
          'camporee_member_id': 6,
          'club_name': ' ',
          'users': {'name': '', 'paternal_last_name': null},
        },
        {'club_name': 'no id'},
      ],
      'payments': [
        {
          'camporee_payment_id': 'a1b2c3d4-0000-4000-8000-000000000001',
          'amount': '350.00',
          'payment_type': 'inscription',
          'reference': 'REF1',
          'notes': null,
          'voucher_url': 'https://r2/x.jpg',
          'paid_at': '2026-04-30T00:00:00.000Z',
          'created_at': '2026-05-03T10:00:00Z',
          'camporee_member': {
            'club_name': 'Orión',
            'users': {
              'name': 'Luis',
              'paternal_last_name': 'Gómez',
              'maternal_last_name': 'Ruiz',
            },
          },
        },
        {
          'camporee_payment_id': 'p2',
          'amount': 12.5,
          'payment_type': 'weird',
        },
        {'amount': '1'},
      ],
    };

    test('parses the three lists', () {
      final p = SupervisionUnionCamporeeModel.parsePending(payload);
      expect(p.clubs.map((e) => e.id), [3]);
      expect(p.clubs.single.clubName, '');
      expect(p.members.map((e) => e.id), [5, 6]);
      expect(p.payments.length, 2);
      expect(p.total, 5);
    });

    test('member names are joined and blanks become empty', () {
      final p = SupervisionUnionCamporeeModel.parsePending(payload);
      expect(p.members[0].fullName, 'Ana Pérez');
      expect(p.members[0].clubName, 'Orión');
      expect(p.members[0].insuranceVerified, isTrue);
      expect(p.members[1].fullName, '');
      expect(p.members[1].clubName, '');
      expect(p.members[1].insuranceVerified, isFalse);
    });

    test('payment amount as string and number, UUID id, calendar paid date',
        () {
      final p = SupervisionUnionCamporeeModel.parsePending(payload);
      final a = p.payments[0];
      expect(a.id, 'a1b2c3d4-0000-4000-8000-000000000001');
      expect(a.amount, 350.0);
      expect(a.type, SupervisionCamporeePaymentType.inscription);
      expect(a.memberName, 'Luis Gómez Ruiz');
      expect(a.clubName, 'Orión');
      expect(a.reference, 'REF1');
      expect(a.notes, isNull);
      expect(a.voucherUrl, 'https://r2/x.jpg');
      expect(a.paidAt, DateTime(2026, 4, 30));
      final b = p.payments[1];
      expect(b.amount, 12.5);
      expect(b.type, SupervisionCamporeePaymentType.unknown);
      expect(b.memberName, '');
      expect(b.paidAt, isNull);
    });

    test('non-map payload yields empty', () {
      expect(SupervisionUnionCamporeeModel.parsePending(null),
          SupervisionCamporeePending.empty);
      expect(
          SupervisionUnionCamporeeModel.parsePending({'clubs': 'x'}).total, 0);
    });

    test('payment type parsing is case-insensitive', () {
      expect(SupervisionCamporeePaymentType.parse(' MATERIALS '),
          SupervisionCamporeePaymentType.materials);
      expect(SupervisionCamporeePaymentType.parse('other'),
          SupervisionCamporeePaymentType.other);
      expect(SupervisionCamporeePaymentType.parse(3),
          SupervisionCamporeePaymentType.unknown);
    });
  });

  group('clubs with names payload', () {
    test('reads club, section type and registrar names', () {
      final clubs = SupervisionUnionCamporeeModel.parseClubsWithNames([
        {
          'camporee_club_id': 4,
          'created_at': '2026-05-01T10:00:00Z',
          'club_sections': {
            'club_types': {'club_type_id': 1, 'name': 'Conquistadores'},
            'clubs': {'club_id': 2, 'name': 'Orión'},
          },
          'registrar': {
            'user_id': 'u',
            'name': 'Mario',
            'paternal_last_name': 'Díaz',
            'maternal_last_name': null,
          },
        },
        {'camporee_club_id': 5, 'registrar': null},
        {'club_sections': {}},
      ]);
      expect(clubs.map((e) => e.id), [4, 5]);
      expect(clubs[0].clubName, 'Orión');
      expect(clubs[0].sectionName, 'Conquistadores');
      expect(clubs[0].registeredByName, 'Mario Díaz');
      expect(clubs[0].createdAt, isNotNull);
      expect(clubs[1].clubName, '');
      expect(clubs[1].sectionName, '');
      expect(clubs[1].registeredByName, isNull);
    });
  });
}
