import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/investiture_requests/presentation/utils/investiture_error_message.dart';

import 'presentation/investiture_test_harness.dart';

void main() {
  setUpAll(initInvestitureTestEnv);

  group('investitureErrorMessage', () {
    test('uses the message of a Failure', () {
      expect(
        investitureErrorMessage(const ServerFailure(message: 'Sin conexión')),
        'Sin conexión',
      );
    });

    test('falls back to the generic translated text for anything else', () {
      final generic = tr('investiture_requests.errors.generic');
      expect(investitureErrorMessage(StateError('boom')), generic);
      expect(investitureErrorMessage(null), generic);
      expect(
          investitureErrorMessage(const ServerFailure(message: '')), generic);
    });
  });
}
