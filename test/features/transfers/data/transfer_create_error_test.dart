import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/transfers/data/datasources/transfer_remote_data_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('transferCreateErrorMessage', () {
    test('known codes get the app copy, not the server text', () {
      expect(
        transferCreateErrorMessage(
          code: 'REQUEST_TRANSFER_PENDING_EXISTS',
          message: 'El usuario ya tiene una solicitud de traslado pendiente',
          hasResponse: true,
        ),
        'transfers.errors.pending_exists'.tr(),
      );
      expect(
        transferCreateErrorMessage(
          code: 'REQUEST_TRANSFER_SAME_SECTION',
          hasResponse: true,
        ),
        'transfers.errors.same_section'.tr(),
      );
    });

    test('a 400 with a list message reads the first constraint', () {
      expect(
        transferCreateErrorMessage(
          message: [
            {
              'property': 'to_section_id',
              'constraints': {'isInt': 'to_section_id debe ser entero'},
            },
          ],
          hasResponse: true,
        ),
        'to_section_id debe ser entero',
      );
    });

    test('no response is a network error; unknown falls back', () {
      expect(transferCreateErrorMessage(hasResponse: false),
          'common.error_network'.tr());
      expect(transferCreateErrorMessage(hasResponse: true),
          'transfers.errors.create'.tr());
    });
  });
}
