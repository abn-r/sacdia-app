import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/camporees/data/models/camporee_model.dart';

void main() {
  group('CamporeeModel.fromJson', () {
    test('keeps start/end calendar days from UTC midnight payload', () {
      final model = CamporeeModel.fromJson({
        'local_camporee_id': 73,
        'name': 'Camporee QA 19 ago 2026',
        'start_date': '2026-08-21T00:00:00.000Z',
        'end_date': '2026-08-23T00:00:00.000Z',
        'local_camporee_place': 'Campo de prueba ACV',
        'includes_adventurers': false,
        'includes_pathfinders': true,
        'includes_master_guides': false,
        'active': true,
      });

      expect(model.startDate.day, 21);
      expect(model.endDate.day, 23);
      expect(model.startDate.month, 8);
      expect(model.endDate.month, 8);
    });
  });
}
