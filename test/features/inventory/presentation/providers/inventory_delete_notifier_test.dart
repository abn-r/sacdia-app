import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:sacdia_app/features/inventory/domain/usecases/delete_inventory_item.dart';
import 'package:sacdia_app/features/inventory/presentation/providers/inventory_providers.dart';

import '../../../../support/riverpod_test_support.dart';

/// Delete that takes a moment, like a real network call.
class _SlowDelete implements DeleteInventoryItem {
  _SlowDelete({this.failure});

  final Failure? failure;

  @override
  InventoryRepository get repository => throw UnimplementedError();

  @override
  Future<Either<Failure, void>> call(DeleteInventoryItemParams params) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final failure = this.failure;
    return failure == null ? const Right(null) : Left(failure);
  }
}

void main() {
  // The item detail view only `ref.read`s this notifier, so nothing listens to
  // it. An autoDispose provider is then disposed while the request is in
  // flight, and writing `state` after the await threw.
  test('deleteItem completes when nothing listens to the notifier', () async {
    final container = createTestContainer(overrides: [
      deleteInventoryItemUseCaseProvider.overrideWithValue(_SlowDelete()),
    ]);

    final ok = await container
        .read(inventoryDeleteNotifierProvider.notifier)
        .deleteItem(5);

    expect(ok, isTrue);
    final state = container.read(inventoryDeleteNotifierProvider);
    expect(state.success, isTrue);
    expect(state.isLoading, isFalse);
  });

  test('a failed delete reports false and keeps the message', () async {
    final container = createTestContainer(overrides: [
      deleteInventoryItemUseCaseProvider.overrideWithValue(
          _SlowDelete(failure: const ServerFailure(message: 'boom'))),
    ]);

    final ok = await container
        .read(inventoryDeleteNotifierProvider.notifier)
        .deleteItem(5);

    expect(ok, isFalse);
    expect(
        container.read(inventoryDeleteNotifierProvider).errorMessage, 'boom');
  });
}
