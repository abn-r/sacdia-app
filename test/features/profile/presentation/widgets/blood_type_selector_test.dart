import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/profile/presentation/widgets/blood_type_selector.dart';

void main() {
  group('BloodType', () {
    test('maps backend enum keys to user-facing display labels', () {
      expect(BloodType.fromDisplay('O_POSITIVE'), BloodType.oPos);
      expect(BloodType.displayFor('O_POSITIVE'), 'O+');
    });

    test('keeps display labels as display labels', () {
      expect(BloodType.fromDisplay('AB-'), BloodType.abNeg);
      expect(BloodType.displayFor('AB-'), 'AB-');
    });
  });
}
