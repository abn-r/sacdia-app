import '../entities/payment_order.dart';

/// Where an order's step stands.
enum OrderStepKind { done, current, rejected, pending }

/// The steps an order goes through. The last one depends on the purpose
/// (insured people, registered people), so it is one id the screen words.
enum OrderStepId {
  issued,
  pay,
  proofSent,
  review,
  proofRejected,
  approved,
  outcome,
  cancelled,
  expired,
}

class OrderStep {
  const OrderStep(this.id, this.kind);

  final OrderStepId id;
  final OrderStepKind kind;

  @override
  bool operator ==(Object other) =>
      other is OrderStep && other.id == id && other.kind == kind;

  @override
  int get hashCode => Object.hash(id, kind);

  @override
  String toString() => 'OrderStep($id, $kind)';
}

/// Every state of an order in order, and the 1-based number of the current
/// one ("Step 2 of 4").
class OrderStatePath {
  const OrderStatePath({required this.steps, required this.current});

  final List<OrderStep> steps;
  final int current;

  int get total => steps.length;
}

/// The path of [status]: the screen shows only the current step and lets the
/// director open the whole list.
OrderStatePath orderStatePath(PaymentOrderStatus status) {
  switch (status) {
    case PaymentOrderStatus.issued:
      return const OrderStatePath(current: 2, steps: [
        OrderStep(OrderStepId.issued, OrderStepKind.done),
        OrderStep(OrderStepId.pay, OrderStepKind.current),
        OrderStep(OrderStepId.review, OrderStepKind.pending),
        OrderStep(OrderStepId.outcome, OrderStepKind.pending),
      ]);
    case PaymentOrderStatus.proofSubmitted:
      return const OrderStatePath(current: 3, steps: [
        OrderStep(OrderStepId.issued, OrderStepKind.done),
        OrderStep(OrderStepId.proofSent, OrderStepKind.done),
        OrderStep(OrderStepId.review, OrderStepKind.current),
        OrderStep(OrderStepId.outcome, OrderStepKind.pending),
      ]);
    case PaymentOrderStatus.proofRejected:
      return const OrderStatePath(current: 3, steps: [
        OrderStep(OrderStepId.issued, OrderStepKind.done),
        OrderStep(OrderStepId.proofSent, OrderStepKind.done),
        OrderStep(OrderStepId.proofRejected, OrderStepKind.rejected),
        OrderStep(OrderStepId.outcome, OrderStepKind.pending),
      ]);
    case PaymentOrderStatus.approved:
      return const OrderStatePath(current: 4, steps: [
        OrderStep(OrderStepId.issued, OrderStepKind.done),
        OrderStep(OrderStepId.proofSent, OrderStepKind.done),
        OrderStep(OrderStepId.approved, OrderStepKind.done),
        OrderStep(OrderStepId.outcome, OrderStepKind.done),
      ]);
    case PaymentOrderStatus.cancelled:
      return const OrderStatePath(current: 2, steps: [
        OrderStep(OrderStepId.issued, OrderStepKind.done),
        OrderStep(OrderStepId.cancelled, OrderStepKind.rejected),
      ]);
    case PaymentOrderStatus.expired:
      return const OrderStatePath(current: 2, steps: [
        OrderStep(OrderStepId.issued, OrderStepKind.done),
        OrderStep(OrderStepId.expired, OrderStepKind.rejected),
      ]);
  }
}
