import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/profile/presentation/utils/edit_profile_payload_builder.dart';

void main() {
  group('buildEditProfilePayload', () {
    test('omits blank optional phone to satisfy backend validation', () {
      final payload = buildEditProfilePayload(
        name: ' Abner ',
        paternalSurname: ' Reyes ',
        maternalSurname: ' Ramírez ',
        phone: '   ',
        address: '',
        genderApiKey: 'M',
        birthdate: DateTime.utc(1994, 6, 3, 6),
        baptized: true,
        baptismDate: DateTime.utc(2026, 3, 25),
      );

      expect(payload, isNot(contains('phone')));
      expect(payload, isNot(contains('address')));
      expect(payload['name'], 'Abner');
      expect(payload['paternal_last_name'], 'Reyes');
      expect(payload['maternal_last_name'], 'Ramírez');
      expect(payload['gender'], 'M');
      expect(payload['birthday'], '1994-06-03T06:00:00.000Z');
      expect(payload['baptism'], isTrue);
      expect(payload['baptism_date'], '2026-03-25T00:00:00.000Z');
    });

    test('keeps non-empty phone and address trimmed', () {
      final payload = buildEditProfilePayload(
        name: 'Abner',
        paternalSurname: '',
        maternalSurname: '',
        phone: ' +52 55 1234 5678 ',
        address: ' Av. Reforma 123 ',
        genderApiKey: null,
        birthdate: null,
        baptized: false,
        baptismDate: DateTime.utc(2026, 3, 25),
      );

      expect(payload['phone'], '+52 55 1234 5678');
      expect(payload['address'], 'Av. Reforma 123');
      expect(payload['baptism'], isFalse);
      expect(payload, isNot(contains('baptism_date')));
    });
  });
}
