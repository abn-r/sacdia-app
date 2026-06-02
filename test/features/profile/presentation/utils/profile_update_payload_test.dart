import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/profile/presentation/utils/profile_update_payload.dart';

void main() {
  group('buildProfileUpdatePayload', () {
    test('does not include legacy invisible phone/address fields', () {
      final payload = buildProfileUpdatePayload(
        name: ' Abner ',
        paternalLastName: ' Reyes ',
        maternalLastName: ' Ramírez ',
        baptism: false,
      );

      expect(payload, isNot(contains('phone')));
      expect(payload, isNot(contains('address')));
      expect(payload['name'], 'Abner');
      expect(payload['paternal_last_name'], 'Reyes');
      expect(payload['maternal_last_name'], 'Ramírez');
      expect(payload['baptism'], isFalse);
    });

    test('omits baptism_date when baptism is false', () {
      final payload = buildProfileUpdatePayload(
        name: 'Abner',
        paternalLastName: 'Reyes',
        maternalLastName: 'Ramírez',
        baptism: false,
        baptismDate: DateTime.utc(2026, 3, 25),
      );

      expect(payload, isNot(contains('baptism_date')));
    });
  });
}
