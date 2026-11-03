import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/finances/domain/entities/finance_category.dart';
import 'package:sacdia_app/features/finances/domain/entities/transaction.dart';
import 'package:sacdia_app/features/finances/domain/repositories/finances_repository.dart';
import 'package:sacdia_app/features/finances/domain/usecases/create_transaction.dart';
import 'package:sacdia_app/features/finances/domain/usecases/delete_transaction.dart';
import 'package:sacdia_app/features/finances/domain/usecases/update_transaction.dart';
import 'package:sacdia_app/features/finances/domain/usecases/upload_finance_evidence.dart';
import 'package:sacdia_app/features/finances/presentation/providers/finances_providers.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';

import '../../../../support/riverpod_test_support.dart';

const _delay = Duration(milliseconds: 20);

final _transaction = FinanceTransaction(
  id: 4,
  type: TransactionType.income,
  amount: 50,
  description: 'Cuota',
  date: DateTime(2026, 11, 3),
  year: 2026,
  month: 11,
  category: const FinanceCategory(id: 1, name: 'Cuotas', typeCode: 0),
  registeredByName: 'Ana',
  registeredAt: DateTime(2026, 11, 3),
);

final _evidence = FinanceEvidence(
  id: 1,
  financeId: 4,
  url: 'https://cdn/e.jpg',
  fileName: 'e.jpg',
  fileType: 'image/jpeg',
  uploadedById: 'u1',
  uploadedAt: DateTime(2026, 11, 3),
  active: true,
);

/// Use cases that take a moment, like a real network call.
Future<Either<Failure, T>> _slow<T>(T value, Failure? failure) async {
  await Future<void>.delayed(_delay);
  return failure == null ? Right(value) : Left(failure);
}

class _SlowCreate implements CreateTransaction {
  _SlowCreate(this.failure);

  final Failure? failure;

  @override
  FinancesRepository get repository => throw UnimplementedError();

  @override
  Future<Either<Failure, FinanceTransaction>> call(
          CreateTransactionParams params) =>
      _slow(_transaction, failure);
}

class _SlowUpdate implements UpdateTransaction {
  _SlowUpdate(this.failure);

  final Failure? failure;

  @override
  FinancesRepository get repository => throw UnimplementedError();

  @override
  Future<Either<Failure, FinanceTransaction>> call(
          UpdateTransactionParams params) =>
      _slow(_transaction, failure);
}

class _SlowDelete implements DeleteTransaction {
  _SlowDelete(this.failure);

  final Failure? failure;

  @override
  FinancesRepository get repository => throw UnimplementedError();

  @override
  Future<Either<Failure, void>> call({required int financeId}) =>
      _slow<void>(null, failure);
}

class _SlowUpload implements UploadFinanceEvidence {
  _SlowUpload(this.failure);

  final Failure? failure;

  @override
  FinancesRepository get repository => throw UnimplementedError();

  @override
  Future<Either<Failure, FinanceEvidence>> call(
          UploadFinanceEvidenceParams params) =>
      _slow(_evidence, failure);
}

void main() {
  // The finance views only `ref.read` this notifier, so nothing listens to it.
  // An autoDispose provider is then disposed while the request is in flight,
  // and touching `ref`/`state` after the await threw.
  final overrides = [
    createTransactionUseCaseProvider.overrideWithValue(_SlowCreate(null)),
    updateTransactionUseCaseProvider.overrideWithValue(_SlowUpdate(null)),
    deleteTransactionUseCaseProvider.overrideWithValue(_SlowDelete(null)),
    uploadFinanceEvidenceUseCaseProvider.overrideWithValue(_SlowUpload(null)),
    clubContextProvider.overrideWith((ref) async => null),
  ];

  test('save (create) completes when nothing listens', () async {
    final container = createTestContainer(overrides: overrides);

    final ok =
        await container.read(transactionFormNotifierProvider.notifier).save(
              clubId: 1,
              categoryId: 1,
              amount: 50,
              description: 'Cuota',
              date: DateTime(2026, 11, 3),
              year: 2026,
              month: 11,
            );

    expect(ok, isTrue);
    expect(container.read(transactionFormNotifierProvider).success, isTrue);
    expect(container.read(transactionFormNotifierProvider).savedTransaction,
        _transaction);
  });

  test('save (update) completes when nothing listens', () async {
    final container = createTestContainer(overrides: overrides);

    final ok =
        await container.read(transactionFormNotifierProvider.notifier).save(
              clubId: 1,
              categoryId: 1,
              amount: 50,
              description: 'Cuota',
              date: DateTime(2026, 11, 3),
              year: 2026,
              month: 11,
              existingId: 4,
            );

    expect(ok, isTrue);
    expect(container.read(transactionFormNotifierProvider).success, isTrue);
  });

  test('delete completes when nothing listens', () async {
    final container = createTestContainer(overrides: overrides);

    final ok = await container
        .read(transactionFormNotifierProvider.notifier)
        .delete(financeId: 4);

    expect(ok, isTrue);
    expect(container.read(transactionFormNotifierProvider).success, isTrue);
    expect(container.read(transactionFormNotifierProvider).isLoading, isFalse);
  });

  test('uploadEvidence completes when nothing listens', () async {
    final container = createTestContainer(overrides: overrides);

    final ok = await container
        .read(transactionFormNotifierProvider.notifier)
        .uploadEvidence(
          financeId: 4,
          filePath: '/tmp/e.jpg',
          fileName: 'e.jpg',
          mimeType: 'image/jpeg',
        );

    expect(ok, isTrue);
    expect(container.read(transactionFormNotifierProvider).success, isTrue);
  });

  test('a failed delete reports false and keeps the message', () async {
    final container = createTestContainer(overrides: [
      deleteTransactionUseCaseProvider
          .overrideWithValue(_SlowDelete(const ServerFailure(message: 'boom'))),
    ]);

    final ok = await container
        .read(transactionFormNotifierProvider.notifier)
        .delete(financeId: 4);

    expect(ok, isFalse);
    expect(
        container.read(transactionFormNotifierProvider).errorMessage, 'boom');
  });
}
