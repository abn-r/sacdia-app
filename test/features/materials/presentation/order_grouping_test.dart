import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/materials/domain/entities/material_receipt_status.dart';
import 'package:sacdia_app/features/materials/domain/entities/material_status.dart';
import 'package:sacdia_app/features/materials/presentation/utils/order_presentation.dart';

import '../support/materials_test_support.dart';

void main() {
  test('approved with no receipt needs paying, a rejected one needs another',
      () {
    expect(
      orderAttention(testOrder()),
      OrderAttention.pay,
    );
    expect(
      orderAttention(testOrder(receipts: [
        testReceipt(status: MaterialReceiptStatus.rechazado),
      ])),
      OrderAttention.uploadAnother,
    );
    expect(
      orderAttention(testOrder(receipts: [testReceipt()])),
      OrderAttention.none,
    );
  });

  test('the newest receipt decides', () {
    final order = testOrder(receipts: [
      testReceipt(
        status: MaterialReceiptStatus.rechazado,
        createdAt: DateTime(2026, 11, 14),
      ),
      testReceipt(createdAt: DateTime(2026, 11, 16)),
    ]);
    expect(orderAttention(order), OrderAttention.none);
  });

  test('orders split into attention, in progress, delivered and cancelled', () {
    final groups = groupOrders([
      testOrder(id: 'pay'),
      testOrder(
        id: 'again',
        receipts: [testReceipt(status: MaterialReceiptStatus.rechazado)],
      ),
      testOrder(id: 'wait', receipts: [testReceipt()]),
      testOrder(id: 'review', status: MaterialStatus.enRevision, folio: null),
      testOrder(id: 'paid', status: MaterialStatus.pagada),
      testOrder(id: 'done', status: MaterialStatus.entregada),
      testOrder(id: 'gone', status: MaterialStatus.cancelada),
    ]);

    expect(
        groups.attention.map((o) => o.id), unorderedEquals(['pay', 'again']));
    expect(groups.inProgress.map((o) => o.id),
        unorderedEquals(['wait', 'review', 'paid']));
    expect(groups.delivered.map((o) => o.id), ['done']);
    expect(groups.cancelled.map((o) => o.id), ['gone']);
  });

  test('newest first inside a group', () {
    final groups = groupOrders([
      testOrder(id: 'old', status: MaterialStatus.entregada),
      testOrder(
        id: 'new',
        status: MaterialStatus.entregada,
        createdAt: DateTime(2026, 11, 17),
      ),
    ]);
    expect(groups.delivered.map((o) => o.id), ['new', 'old']);
  });
}
