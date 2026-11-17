import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/payment_orders/domain/entities/payment_order.dart';
import 'package:sacdia_app/features/payment_orders/domain/utils/order_state_path.dart';

void main() {
  List<OrderStepKind> kinds(OrderStatePath path) =>
      path.steps.map((s) => s.kind).toList();

  test('issued: pay and upload the receipt is the current step (2 of 4)', () {
    final path = orderStatePath(PaymentOrderStatus.issued);

    expect(path.current, 2);
    expect(path.total, 4);
    expect(path.steps[path.current - 1].id, OrderStepId.pay);
    expect(kinds(path), [
      OrderStepKind.done,
      OrderStepKind.current,
      OrderStepKind.pending,
      OrderStepKind.pending,
    ]);
  });

  test('receipt submitted: the field reviewing is current (3 of 4)', () {
    final path = orderStatePath(PaymentOrderStatus.proofSubmitted);

    expect(path.current, 3);
    expect(path.steps.map((s) => s.id), [
      OrderStepId.issued,
      OrderStepId.proofSent,
      OrderStepId.review,
      OrderStepId.outcome,
    ]);
    expect(path.steps[2].kind, OrderStepKind.current);
  });

  test('receipt rejected: a rejected step replaces the review', () {
    final path = orderStatePath(PaymentOrderStatus.proofRejected);

    expect(path.current, 3);
    expect(path.steps[2],
        const OrderStep(OrderStepId.proofRejected, OrderStepKind.rejected));
    expect(path.steps.last.kind, OrderStepKind.pending);
  });

  test('approved: everything done', () {
    final path = orderStatePath(PaymentOrderStatus.approved);

    expect(path.current, 4);
    expect(kinds(path).every((k) => k == OrderStepKind.done), isTrue);
  });

  test('cancelled and expired end in a rejected step (2 of 2)', () {
    for (final status in [
      PaymentOrderStatus.cancelled,
      PaymentOrderStatus.expired,
    ]) {
      final path = orderStatePath(status);
      expect(path.total, 2);
      expect(path.current, 2);
      expect(path.steps.last.kind, OrderStepKind.rejected);
    }
  });

  test('every status has exactly one current or rejected step', () {
    for (final status in PaymentOrderStatus.values) {
      final path = orderStatePath(status);
      final active = path.steps
          .where((s) =>
              s.kind == OrderStepKind.current ||
              s.kind == OrderStepKind.rejected)
          .length;
      if (status == PaymentOrderStatus.approved) {
        expect(active, 0);
      } else {
        expect(active, 1, reason: '$status');
      }
      expect(path.current, inInclusiveRange(1, path.total));
    }
  });
}
