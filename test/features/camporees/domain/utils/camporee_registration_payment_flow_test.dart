import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/camporees/domain/utils/camporee_registration_payment_flow.dart';

void main() {
  test('loading gana aunque haya un enabled previo', () {
    expect(
      camporeeRegistrationPaymentFlow(
        isLoading: true,
        hasError: false,
        enabled: false,
      ),
      CamporeeRegistrationPaymentFlow.loading,
    );
  });

  test('error no cae al register legacy', () {
    expect(
      camporeeRegistrationPaymentFlow(
        isLoading: false,
        hasError: true,
        enabled: true,
      ),
      CamporeeRegistrationPaymentFlow.unavailable,
    );
  });

  test('enabled pinta emisión de orden', () {
    expect(
      camporeeRegistrationPaymentFlow(
        isLoading: false,
        hasError: false,
        enabled: true,
      ),
      CamporeeRegistrationPaymentFlow.paymentOrder,
    );
  });

  test('null o disabled conserva el flujo legacy', () {
    expect(
      camporeeRegistrationPaymentFlow(
        isLoading: false,
        hasError: false,
      ),
      CamporeeRegistrationPaymentFlow.legacy,
    );
  });
}
