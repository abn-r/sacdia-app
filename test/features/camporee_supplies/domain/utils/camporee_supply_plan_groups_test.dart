import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/camporee_supplies/domain/entities/camporee_supply_plan.dart';
import 'package:sacdia_app/features/camporee_supplies/domain/utils/camporee_supply_plan_groups.dart';

void main() {
  const morning = CamporeeSupplySlot(
    slotId: 'am',
    label: 'Mañana',
    deliverTime: '07:00',
    sortOrder: 1,
  );
  const night = CamporeeSupplySlot(
    slotId: 'pm',
    label: 'Noche',
    deliverTime: '19:00',
    sortOrder: 3,
  );
  const afternoon = CamporeeSupplySlot(
    slotId: 'md',
    label: 'Tarde',
    deliverTime: '13:00',
    sortOrder: 2,
  );

  group('groupCamporeeSupplyLines', () {
    test('should keep every camp day and nest lines by slot order', () {
      final groups = groupCamporeeSupplyLines(
        dates: const ['2026-08-21', '2026-08-22'],
        slots: const [night, morning, afternoon],
        lines: const [
          CamporeeSupplyLineInput(
            date: '2026-08-22',
            slotId: 'am',
            productId: 'water',
            qty: 6,
          ),
          CamporeeSupplyLineInput(
            date: '2026-08-21',
            slotId: 'pm',
            productId: 'milk',
            qty: 2,
          ),
          CamporeeSupplyLineInput(
            date: '2026-08-21',
            slotId: 'am',
            productId: 'ice',
            qty: 2,
          ),
          CamporeeSupplyLineInput(
            date: '2026-08-21',
            slotId: 'am',
            productId: 'water',
            qty: 6,
          ),
        ],
      );

      expect(groups, hasLength(2));
      expect(groups.first.dayNumber, 1);
      expect(
          groups.first.slots.map((bucket) => bucket.slot.slotId), ['am', 'pm']);
      expect(
        groups.first.slots.first.lines.map((line) => line.productId),
        ['ice', 'water'],
      );
      expect(groups.last.dayNumber, 2);
      expect(groups.last.slots.single.slot.slotId, 'am');
    });

    test('should omit empty slots but keep empty days', () {
      final groups = groupCamporeeSupplyLines(
        dates: const ['2026-08-21', '2026-08-22'],
        slots: const [morning, afternoon],
        lines: const [],
      );

      expect(groups.first.isEmpty, isTrue);
      expect(groups.last.isEmpty, isTrue);
      expect(groups.first.slots, isEmpty);
    });
  });

  group('estimateCamporeeSupplyTotal', () {
    test('should snapshot qty times unit cost in centavos', () {
      expect(
        estimateCamporeeSupplyTotal(
          lines: const [
            CamporeeSupplyLineInput(
              date: '2026-08-21',
              slotId: 'am',
              productId: 'ice',
              qty: 2,
            ),
            CamporeeSupplyLineInput(
              date: '2026-08-21',
              slotId: 'am',
              productId: 'water',
              qty: 1.5,
            ),
          ],
          products: const [
            CamporeeSupplyProduct(
              productId: 'ice',
              name: 'Hielo',
              uom: 'BAG',
              unitCostCentavos: 4500,
            ),
            CamporeeSupplyProduct(
              productId: 'water',
              name: 'Agua',
              uom: 'L',
              unitCostCentavos: 2000,
            ),
          ],
        ),
        12000,
      );
    });
  });
}
