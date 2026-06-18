import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/inventory/presentation/providers/inventory_providers.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';

void main() {
  group('inventory context helpers', () {
    test('uses active club section id as inventory resource id', () {
      const context = ClubContext(
        clubId: 1,
        sectionId: 42,
        clubTypeId: 2,
        clubTypeName: 'Conquistadores',
      );

      expect(inventoryResourceIdFromContext(context), 42);
    });

    test('keeps instanceType derived from the active club type', () {
      expect(mapClubTypeToInstanceType('Aventureros'), 'adv');
      expect(mapClubTypeToInstanceType('Conquistadores'), 'pathf');
      expect(mapClubTypeToInstanceType('Guías Mayores'), 'mg');
    });
  });
}
