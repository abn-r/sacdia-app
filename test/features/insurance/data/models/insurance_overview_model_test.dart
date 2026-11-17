import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/insurance/data/models/insurance_overview_model.dart';
import 'package:sacdia_app/features/insurance/domain/entities/insurance_conflict.dart';
import 'package:sacdia_app/features/insurance/domain/entities/insurance_overview.dart';
import 'package:sacdia_app/features/payment_orders/domain/entities/payment_order.dart';

Map<String, dynamic> _json() => {
      'year': {
        'ecclesiastical_year_id': 9,
        'label': '2027',
        'start_date': '2027-01-01',
        'end_date': '2027-12-31',
      },
      'cycle': {
        'insurance_cycle_config_id': 4,
        'unit_cost': '150.00',
        'purchase_deadline': '2027-02-28',
        'currency': 'MXN',
      },
      'counts': {'total': 4, 'covered': 1, 'in_process': 2, 'uninsured': 1},
      'free_coverages_count': 1,
      'people': [
        {
          'user_id': 'u-1',
          'name': 'Diego Campos',
          'picture': null,
          'role_label': 'Amigo',
          'is_staff': false,
          'status': 'uninsured',
          'coverage': null,
          'active_order': null,
        },
        {
          'user_id': 'u-2',
          'name': 'Mateo Herrera',
          'picture': 'https://cdn/x.png',
          'role_label': 'counselor',
          'is_staff': true,
          'status': 'in_order',
          'coverage': null,
          'active_order': {
            'order_id': 'o-1',
            'folio': 'ORD20270044',
            'status': 'ISSUED',
            'expires_at': '2027-02-21T00:00:00.000Z',
          },
        },
        {
          'user_id': 'u-3',
          'name': 'Sofía Navarro',
          'role_label': 'Explorador',
          'is_staff': false,
          'status': 'proof_rejected',
          'active_order': {
            'order_id': 'o-2',
            'folio': 'ORD20270041',
            'status': 'PROOF_REJECTED',
            'expires_at': null,
          },
        },
        {
          'user_id': 'u-4',
          'name': 'Joaquín Salas',
          'role_label': 'Pionero',
          'is_staff': false,
          'status': 'covered',
          'coverage': {
            'source': 'reassigned',
            'paid_in_section_name': 'Conquistadores',
            'paid_in_club_name': 'Club Orión',
            'order_folio': 'ORD20270031',
            'approved_at': '2027-02-03T10:00:00.000Z',
            'valid_until': '2027-12-31',
            'reassigned_from_name': 'Ximena Lara',
            'reassigned_by_name': 'Natalia Rojas',
            'reassigned_at': '2027-02-06T10:00:00.000Z',
          },
          'active_order': null,
        },
      ],
    };

void main() {
  group('InsuranceOverviewModel.fromJson', () {
    test('parses year, cycle, counts and people', () {
      final overview = InsuranceOverviewModel.fromJson(_json());

      expect(overview.year?.id, 9);
      expect(overview.year?.label, '2027');
      expect(overview.year?.endDate, DateTime(2027, 12, 31));
      expect(overview.cycle?.cycleConfigId, 4);
      expect(overview.cycle?.unitCostCentavos, 15000);
      expect(overview.cycle?.purchaseDeadline, DateTime(2027, 2, 28));
      expect(overview.counts.total, 4);
      expect(overview.counts.inProcess, 2);
      expect(overview.freeCoveragesCount, 1);
      expect(overview.people, hasLength(4));
    });

    test('keeps the server order and maps each status', () {
      final people = InsuranceOverviewModel.fromJson(_json()).people;

      expect(
        people.map((p) => p.status),
        [
          InsurancePersonStatus.uninsured,
          InsurancePersonStatus.inOrder,
          InsurancePersonStatus.proofRejected,
          InsurancePersonStatus.covered,
        ],
      );
      expect(people[1].isStaff, isTrue);
      expect(people[1].roleLabel, 'counselor');
      expect(people[1].picture, 'https://cdn/x.png');
    });

    test('parses the active order with the payment order status', () {
      final order =
          InsuranceOverviewModel.fromJson(_json()).people[1].activeOrder!;

      expect(order.orderId, 'o-1');
      expect(order.folio, 'ORD20270044');
      expect(order.status, PaymentOrderStatus.issued);
      expect(order.expiresAt, isNotNull);
    });

    test('parses a reassigned coverage with its trace', () {
      final coverage =
          InsuranceOverviewModel.fromJson(_json()).people[3].coverage!;

      expect(coverage.source, CoverageSource.reassigned);
      expect(coverage.reassignedFromName, 'Ximena Lara');
      expect(coverage.reassignedByName, 'Natalia Rojas');
      expect(coverage.reassignedAt, isNotNull);
      expect(coverage.orderFolio, 'ORD20270031');
      expect(coverage.validUntil, DateTime(2027, 12, 31));
    });

    test('no cost published: cycle is null', () {
      final json = _json()..['cycle'] = null;

      final overview = InsuranceOverviewModel.fromJson(json);

      expect(overview.cycle, isNull);
      expect(overview.year, isNotNull);
    });

    test('no year: year and cycle are null and the lists stay usable', () {
      final overview = InsuranceOverviewModel.fromJson({
        'year': null,
        'cycle': null,
        'counts': {'total': 0, 'covered': 0, 'in_process': 0, 'uninsured': 0},
        'free_coverages_count': 0,
        'people': <dynamic>[],
      });

      expect(overview.year, isNull);
      expect(overview.cycle, isNull);
      expect(overview.people, isEmpty);
    });

    test('is tolerant: missing and badly typed fields do not throw', () {
      final overview = InsuranceOverviewModel.fromJson({
        'counts': 'oops',
        'people': [
          {'user_id': 7, 'status': 'something_new'},
          'not a map',
        ],
      });

      expect(overview.counts.total, 0);
      expect(overview.people, hasLength(1));
      expect(overview.people.single.userId, '7');
      // An unknown status never reads as insured.
      expect(overview.people.single.status, InsurancePersonStatus.uninsured);
    });

    test('unit_cost accepts strings and numbers', () {
      expect(InsuranceOverviewModel.pesosToCentavos('350.00'), 35000);
      expect(InsuranceOverviewModel.pesosToCentavos(150), 15000);
      expect(InsuranceOverviewModel.pesosToCentavos('12.345'), 1235);
      expect(InsuranceOverviewModel.pesosToCentavos(null), 0);
    });
  });

  group('derived lists', () {
    final overview = InsuranceOverviewModel.fromJson(_json());

    test('uninsured and blocked split the people', () {
      expect(overview.uninsured.map((p) => p.userId), ['u-1']);
      expect(overview.blocked.map((p) => p.userId), ['u-2', 'u-3', 'u-4']);
    });

    test('open orders are grouped from the people active orders', () {
      expect(overview.openOrders.map((o) => o.order.folio),
          ['ORD20270044', 'ORD20270041']);
      expect(overview.rejectedOrders.single.order.folio, 'ORD20270041');
      expect(overview.ordersNeedingReceipt.single.order.folio, 'ORD20270044');
    });

    test('one order holding several people counts them once', () {
      final shared = InsuranceOverview(
        year: null,
        cycle: null,
        counts: const InsuranceCounts(total: 2, inProcess: 2),
        freeCoveragesCount: 0,
        people: const [
          InsurancePerson(
            userId: 'a',
            name: 'A',
            status: InsurancePersonStatus.inOrder,
            activeOrder: InsuranceActiveOrder(
              orderId: 'o',
              folio: 'F1',
              status: PaymentOrderStatus.issued,
            ),
          ),
          InsurancePerson(
            userId: 'b',
            name: 'B',
            status: InsurancePersonStatus.inOrder,
            activeOrder: InsuranceActiveOrder(
              orderId: 'o',
              folio: 'F1',
              status: PaymentOrderStatus.issued,
            ),
          ),
        ],
      );

      expect(shared.openOrders, hasLength(1));
      expect(shared.openOrders.single.peopleCount, 2);
    });

    test('start of year and all covered', () {
      final start = DateTime(2027, 1, 1);
      InsuranceOverview withCounts(InsuranceCounts counts) => InsuranceOverview(
            year: InsuranceYear(
              id: 2,
              label: '2027',
              startDate: start,
              endDate: DateTime(2027, 12, 31),
            ),
            cycle: null,
            counts: counts,
            freeCoveragesCount: 0,
            people: const [],
          );

      expect(
        withCounts(const InsuranceCounts(total: 12, uninsured: 12))
            .isYearStart(DateTime(2027, 2, 10)),
        isTrue,
      );
      // Late in the year nobody covered is not "the year just started".
      expect(
        withCounts(const InsuranceCounts(total: 12, uninsured: 12))
            .isYearStart(DateTime(2027, 11, 17)),
        isFalse,
      );
      expect(
        withCounts(const InsuranceCounts(total: 12, covered: 12)).isAllCovered,
        isTrue,
      );
      expect(
        withCounts(const InsuranceCounts(total: 12, covered: 1, uninsured: 11))
            .isYearStart(DateTime(2027, 2, 10)),
        isFalse,
      );
      expect(
        withCounts(const InsuranceCounts()).isYearStart(DateTime(2027, 2, 10)),
        isFalse,
      );
    });

    test('inProcess groups the three order states', () {
      expect(InsurancePersonStatus.inOrder.inProcess, isTrue);
      expect(InsurancePersonStatus.inReview.inProcess, isTrue);
      expect(InsurancePersonStatus.proofRejected.inProcess, isTrue);
      expect(InsurancePersonStatus.covered.inProcess, isFalse);
      expect(InsurancePersonStatus.uninsured.inProcess, isFalse);
    });
  });

  group('status mapping', () {
    test('fromApi covers every server status', () {
      expect(InsurancePersonStatus.fromApi('covered'),
          InsurancePersonStatus.covered);
      expect(InsurancePersonStatus.fromApi('in_order'),
          InsurancePersonStatus.inOrder);
      expect(InsurancePersonStatus.fromApi('in_review'),
          InsurancePersonStatus.inReview);
      expect(InsurancePersonStatus.fromApi('proof_rejected'),
          InsurancePersonStatus.proofRejected);
      expect(InsurancePersonStatus.fromApi('uninsured'),
          InsurancePersonStatus.uninsured);
      expect(
          InsurancePersonStatus.fromApi(null), InsurancePersonStatus.uninsured);
    });

    test('coverage sources', () {
      expect(CoverageSource.fromApi('paid_here'), CoverageSource.paidHere);
      expect(CoverageSource.fromApi('paid_elsewhere'),
          CoverageSource.paidElsewhere);
      expect(CoverageSource.fromApi('reassigned'), CoverageSource.reassigned);
      expect(CoverageSource.fromApi('???'), CoverageSource.paidHere);
    });
  });

  group('free coverages', () {
    test('parses the items', () {
      final items = InsuranceOverviewModel.freeCoveragesFromJson({
        'count': 1,
        'items': [
          {
            'insurance_assignment_id': 31,
            'holder': {'user_id': 'u-9', 'name': 'Pablo Ruiz'},
            'valid_until': '2027-12-31',
            'order_id': 'o-7',
            'order_folio': 'ORD20270031',
            'left_at': '2027-02-10T00:00:00.000Z',
          },
        ],
      });

      expect(items.single.assignmentId, 31);
      expect(items.single.holderName, 'Pablo Ruiz');
      expect(items.single.holderUserId, 'u-9');
      expect(items.single.orderFolio, 'ORD20270031');
      expect(items.single.leftAt, isNotNull);
    });

    test('drops items without an assignment id', () {
      final items = InsuranceOverviewModel.freeCoveragesFromJson({
        'items': [
          {
            'holder': {'name': 'X'}
          },
        ],
      });

      expect(items, isEmpty);
    });
  });

  group('conflicts from the 409 body', () {
    Map<String, dynamic> body(List<Map<String, dynamic>> conflicts) => {
          'code': 'FIELD_PAYMENT_ORDER_DUPLICATE_BENEFICIARY',
          'message': 'dup',
          'data': {'conflicts': conflicts},
        };

    test('parses already covered and in live order', () {
      final conflicts = InsuranceOverviewModel.conflictsFromBody(body([
        {
          'user_id': 'u-2',
          'name': 'Valeria Ríos',
          'reason': 'already_covered',
          'section_name': 'Aventureros',
          'club_name': 'Club Orión',
          'folio': 'ORD1',
          'valid_until': '2027-12-31',
        },
        {
          'user_id': 'u-3',
          'name': 'Tomás Aguilar',
          'reason': 'in_live_order',
          'section_name': 'Conquistadores',
          'club_name': null,
          'folio': 'ORD2',
          'order_status': 'PROOF_SUBMITTED',
        },
      ]));

      expect(conflicts, hasLength(2));
      expect(conflicts[0].reason, InsuranceConflictReason.alreadyCovered);
      expect(conflicts[0].sectionName, 'Aventureros');
      expect(conflicts[0].validUntil, DateTime(2027, 12, 31));
      expect(conflicts[1].reason, InsuranceConflictReason.inLiveOrder);
      expect(conflicts[1].orderStatus, PaymentOrderStatus.proofSubmitted);
      expect(conflicts[1].clubName, isNull);
    });

    test('an empty or malformed body gives no conflicts', () {
      expect(InsuranceOverviewModel.conflictsFromBody(null), isEmpty);
      expect(InsuranceOverviewModel.conflictsFromBody('x'), isEmpty);
      expect(InsuranceOverviewModel.conflictsFromBody({'data': {}}), isEmpty);
      expect(
        InsuranceOverviewModel.conflictsFromBody({
          'data': {'conflicts': 'nope'},
        }),
        isEmpty,
      );
    });

    test('also accepts a top-level conflicts list', () {
      final conflicts = InsuranceOverviewModel.conflictsFromBody({
        'conflicts': [
          {'user_id': 'u', 'name': 'N', 'reason': 'already_covered'},
        ],
      });

      expect(conflicts.single.userId, 'u');
    });
  });
}
