import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/insurance/domain/entities/insurance_overview.dart';
import 'package:sacdia_app/features/insurance/presentation/providers/insurance_providers.dart';
import 'package:sacdia_app/features/insurance/presentation/views/insurance_person_view.dart';
import 'package:sacdia_app/features/insurance/presentation/views/insurance_view.dart';
import 'package:sacdia_app/features/insurance/presentation/views/issue_insurance_view.dart';
import 'package:sacdia_app/features/insurance/presentation/views/reassign_insurance_view.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:sacdia_app/features/camporee_orders/presentation/providers/camporee_orders_providers.dart';
import 'package:sacdia_app/features/payment_orders/domain/entities/payment_obligation.dart';
import 'package:sacdia_app/features/payment_orders/domain/entities/payment_order.dart';
import 'package:sacdia_app/features/payment_orders/presentation/providers/payment_orders_providers.dart';
import 'package:sacdia_app/features/payment_orders/presentation/views/payment_order_detail_view.dart';
import 'package:sacdia_app/features/payment_orders/presentation/views/payment_orders_view.dart';

import '../../../investiture_requests/presentation/investiture_test_harness.dart';
import '../insurance_test_support.dart';

PaymentOrder _layoutOrder() => PaymentOrder(
      orderId: 'o-44',
      purpose: PaymentOrderPurpose.insurance,
      folioReference: 'ORD20270044',
      currency: 'MXN',
      unitCostCentavos: 35000,
      totalCentavos: 105000,
      status: PaymentOrderStatus.proofRejected,
      expiresAt: DateTime(2027, 2, 21),
      createdAt: DateTime(2027, 2, 7),
      lines: const [
        PaymentOrderLine(
          lineId: 'l1',
          sequence: 1,
          beneficiaryUserId: 'u-3',
          unitCostCentavos: 35000,
          beneficiaryName: 'Mateo Herrera Villalobos de la Torre',
          isStaff: true,
        ),
      ],
      proofs: [
        PaymentOrderProof(
          proofId: 'p',
          fileName: 'r.jpg',
          mimeType: 'image/jpeg',
          status: PaymentOrderProofStatus.rejected,
          rejectReason:
              'El monto del depósito no coincide con el total de la orden.',
          createdAt: DateTime(2027, 2, 10),
        ),
      ],
    );

/// Small phone (320dp) with the largest text: nothing may overflow. A
/// RenderFlex overflow throws and fails the test.
void main() {
  setUpAll(initInvestitureTestEnv);

  const access = InsuranceAccess(
    canIssue: true,
    canReassign: true,
    canViewOrders: true,
  );

  Future<void> pump(WidgetTester tester, Widget view,
      {bool dark = false}) async {
    tester.view.physicalSize = const Size(640, 1400);
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      wrapApp(
        view,
        overrides: [
          clubContextProvider.overrideWith((ref) async => testClubContext),
          insuranceAccessProvider.overrideWith((ref) async => access),
          insuranceOverviewProvider
              .overrideWith((ref) async => mockupOverview()),
          freeCoveragesProvider.overrideWith(
            (ref) async => const [
              FreeCoverage(
                assignmentId: 31,
                holderUserId: 'u-99',
                holderName: 'Pablo Ruiz Hernández de la Fuente',
              ),
            ],
          ),
          paymentOrdersListProvider
              .overrideWith((ref, f) async => [_layoutOrder()]),
          pendingPaymentObligationsProvider
              .overrideWith((ref) async => const <PaymentObligation>[]),
          paymentOrderDetailProvider('o-44')
              .overrideWith((ref) async => _layoutOrder()),
          canIssuePaymentOrdersProvider.overrideWith((ref) async => true),
        ],
      ),
    );
    await settle(tester);
  }

  final screens = <String, Widget>{
    'order detail': const PaymentOrderDetailView(orderId: 'o-44'),
    'orders list':
        const PaymentOrdersView(purpose: PaymentOrderPurpose.insurance),
    'home': const InsuranceView(),
    'issue': const IssueInsuranceView(),
    'reassign': const ReassignInsuranceView(),
    'person (reassigned)': const InsurancePersonView(userId: 'u-9'),
    'person (elsewhere)': const InsurancePersonView(userId: 'u-8'),
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key}: no overflow at 320dp and 200% text',
        (tester) async {
      await pump(tester, entry.value);

      expect(tester.takeException(), isNull);
    });
  }
}
