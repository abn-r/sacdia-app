import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/features/virtual_card/presentation/views/virtual_card_view.dart';

void main() {
  test('maps connection errors to the generic network copy', () {
    expect(
      virtualCardErrorMessageKey(ConnectionException(message: 'timeout')),
      'common.error_network',
    );
  });

  test('maps functional errors to the safe virtual card copy', () {
    expect(
      virtualCardErrorMessageKey(ServerException(message: 'Forbidden', code: 403)),
      'virtual_card.errors.load_failed',
    );
    expect(
      virtualCardErrorMessageKey(Exception('boom')),
      'virtual_card.errors.load_failed',
    );
  });
}
