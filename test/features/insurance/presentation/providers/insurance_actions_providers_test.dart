import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/insurance/domain/entities/insurance_conflict.dart';
import 'package:sacdia_app/features/insurance/presentation/providers/insurance_actions_providers.dart';
import 'package:sacdia_app/features/payment_orders/presentation/providers/payment_orders_providers.dart';

import '../../../../support/riverpod_test_support.dart';
import '../insurance_test_support.dart';

void main() {
  late FakePaymentOrdersRepo repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakePaymentOrdersRepo();
    container = createTestContainer(
      overrides: [paymentOrdersRepositoryProvider.overrideWithValue(repo)],
    );
  });

  group('InsuranceIssueNotifier', () {
    test('no emite sin beneficiarios', () async {
      final order = await container
          .read(insuranceIssueNotifierProvider.notifier)
          .submit(cycleConfigId: 4, beneficiaryUserIds: const []);

      expect(order, isNull);
      expect(repo.keys, isEmpty);
    });

    test('emite con el ciclo, los ids y un Idempotency-Key', () async {
      final order = await container
          .read(insuranceIssueNotifierProvider.notifier)
          .submit(cycleConfigId: 4, beneficiaryUserIds: const ['a', 'b']);

      expect(order?.orderId, 'order-1');
      expect(repo.sentIds.single, ['a', 'b']);
      expect(repo.keys.single, isNotNull);
      expect(repo.keys.single, isNotEmpty);
      expect(
        container.read(insuranceIssueNotifierProvider).issuedOrder?.orderId,
        'order-1',
      );
    });

    test('reintentar la misma selección tras un fallo reusa la llave',
        () async {
      repo.createResult = const Left(ConnectionFailure(message: 'offline'));
      final notifier = container.read(insuranceIssueNotifierProvider.notifier);

      await notifier
          .submit(cycleConfigId: 4, beneficiaryUserIds: const ['a', 'b']);
      // Same people in another order of selection: still the same request.
      await notifier
          .submit(cycleConfigId: 4, beneficiaryUserIds: const ['b', 'a']);

      expect(repo.keys, hasLength(2));
      expect(repo.keys[0], repo.keys[1]);
      expect(
        container.read(insuranceIssueNotifierProvider).errorMessage,
        isNotNull,
      );
    });

    test('otra selección usa otra llave', () async {
      repo.createResult = const Left(ConnectionFailure(message: 'offline'));
      final notifier = container.read(insuranceIssueNotifierProvider.notifier);

      await notifier
          .submit(cycleConfigId: 4, beneficiaryUserIds: const ['a', 'b']);
      await notifier.submit(cycleConfigId: 4, beneficiaryUserIds: const ['a']);

      expect(repo.keys[0], isNot(repo.keys[1]));
    });

    test('tras emitir con éxito la siguiente emisión usa una llave nueva',
        () async {
      final notifier = container.read(insuranceIssueNotifierProvider.notifier);

      await notifier.submit(cycleConfigId: 4, beneficiaryUserIds: const ['a']);
      await notifier.submit(cycleConfigId: 4, beneficiaryUserIds: const ['a']);

      expect(repo.keys[0], isNot(repo.keys[1]));
    });

    test('un 409 deja los conflictos en el estado y no es un error genérico',
        () async {
      repo.createResult = const Left(
        DuplicateBeneficiariesFailure(
          message: 'dup',
          code: 409,
          conflicts: [
            InsuranceConflict(
              userId: 'b',
              name: 'Valeria Ríos',
              reason: InsuranceConflictReason.alreadyCovered,
              sectionName: 'Aventureros',
            ),
          ],
        ),
      );
      final notifier = container.read(insuranceIssueNotifierProvider.notifier);

      final order = await notifier
          .submit(cycleConfigId: 4, beneficiaryUserIds: const ['a', 'b']);

      expect(order, isNull);
      final state = container.read(insuranceIssueNotifierProvider);
      expect(state.conflicts.single.userId, 'b');
      expect(state.errorMessage, isNull);
      expect(state.isSubmitting, isFalse);

      notifier.clearConflicts();
      expect(container.read(insuranceIssueNotifierProvider).conflicts, isEmpty);
    });

    test('después de un conflicto la selección nueva usa llave nueva',
        () async {
      repo.createResult = const Left(
        DuplicateBeneficiariesFailure(message: 'dup', conflicts: [
          InsuranceConflict(
            userId: 'b',
            name: 'B',
            reason: InsuranceConflictReason.inLiveOrder,
          ),
        ]),
      );
      final notifier = container.read(insuranceIssueNotifierProvider.notifier);
      await notifier
          .submit(cycleConfigId: 4, beneficiaryUserIds: const ['a', 'b']);

      repo.createResult = Right(testOrder());
      await notifier.submit(cycleConfigId: 4, beneficiaryUserIds: const ['a']);

      expect(repo.keys[0], isNot(repo.keys[1]));
    });

    test('un error de negocio muestra su mensaje ya traducido', () async {
      repo.createResult = const Left(
        ServerFailure(
          message: 'Elige un ciclo válido',
          code: 400,
          errorCode: 'FIELD_PAYMENT_ORDER_CYCLE_INVALID',
        ),
      );

      await container
          .read(insuranceIssueNotifierProvider.notifier)
          .submit(cycleConfigId: 4, beneficiaryUserIds: const ['a']);

      expect(
        container.read(insuranceIssueNotifierProvider).errorMessage,
        'Elige un ciclo válido',
      );
    });

    test('un error sin código no filtra el texto crudo del servidor', () async {
      repo.createResult = const Left(
        ServerFailure(message: 'Http status error [500]', code: 500),
      );

      await container
          .read(insuranceIssueNotifierProvider.notifier)
          .submit(cycleConfigId: 4, beneficiaryUserIds: const ['a']);

      expect(
        container.read(insuranceIssueNotifierProvider).errorMessage,
        isNot(contains('Http status')),
      );
    });
  });

  group('InsuranceReassignNotifier', () {
    test('pasa el seguro y marca done', () async {
      final ok = await container
          .read(insuranceReassignNotifierProvider.notifier)
          .submit(assignmentId: 31, toUserId: 'u-1');

      expect(ok, isTrue);
      expect(repo.lastReassign, (assignmentId: 31, to: 'u-1'));
      expect(container.read(insuranceReassignNotifierProvider).done, isTrue);
    });

    test('un rechazo del servidor queda en errorMessage', () async {
      repo.reassignResult = const Left(
        ServerFailure(
          message: 'La reasignación no es válida',
          code: 400,
          errorCode: 'INSURANCE_REASSIGNMENT_INVALID',
        ),
      );

      final ok = await container
          .read(insuranceReassignNotifierProvider.notifier)
          .submit(assignmentId: 31, toUserId: 'u-1');

      expect(ok, isFalse);
      final state = container.read(insuranceReassignNotifierProvider);
      expect(state.done, isFalse);
      expect(state.errorMessage, 'La reasignación no es válida');
    });
  });
}
