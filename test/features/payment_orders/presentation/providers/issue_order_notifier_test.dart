import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/payment_orders/domain/entities/payment_order.dart';
import 'package:sacdia_app/features/payment_orders/domain/repositories/payment_orders_repository.dart';
import 'package:sacdia_app/features/payment_orders/presentation/providers/payment_orders_providers.dart';

PaymentOrder _order({String id = 'order-1'}) => PaymentOrder(
      orderId: id,
      purpose: PaymentOrderPurpose.insurance,
      folioReference: 'OP20260001',
      currency: 'MXN',
      unitCostCentavos: 15000,
      totalCentavos: 15000,
      status: PaymentOrderStatus.issued,
      expiresAt: DateTime.utc(2026, 8, 27),
      createdAt: DateTime.utc(2026, 8, 12),
    );

class _FakeRepository implements PaymentOrdersRepository {
  Either<Failure, PaymentOrder> createResult = Right(_order());
  int createInsuranceCalls = 0;
  int? lastCycleConfigId;
  List<String>? lastBeneficiaries;
  int createCamporeeCalls = 0;
  int? lastCamporeeId;
  String? lastCamporeeType;

  @override
  Future<Either<Failure, PaymentOrder>> createInsuranceOrder({
    required int cycleConfigId,
    required List<String> beneficiaryUserIds,
  }) async {
    createInsuranceCalls++;
    lastCycleConfigId = cycleConfigId;
    lastBeneficiaries = beneficiaryUserIds;
    return createResult;
  }

  @override
  Future<Either<Failure, PaymentOrder>> createCamporeeOrder({
    required int camporeeId,
    required List<String> beneficiaryUserIds,
    String camporeeType = 'local',
  }) async {
    createCamporeeCalls++;
    lastCamporeeId = camporeeId;
    lastCamporeeType = camporeeType;
    lastBeneficiaries = beneficiaryUserIds;
    return createResult;
  }

  @override
  Future<Either<Failure, List<PaymentOrder>>> listOrders({
    PaymentOrderPurpose? purpose,
    PaymentOrderStatus? status,
    int? camporeeId,
    int? unionCamporeeId,
    RequestCancelToken? cancelToken,
  }) async =>
      const Right([]);

  @override
  Future<Either<Failure, PaymentOrdersContext>> getContext({
    RequestCancelToken? cancelToken,
  }) async =>
      const Right(
        PaymentOrdersContext(
          enabled: true,
          localFieldId: 1,
          clubSectionId: 1,
        ),
      );

  @override
  Future<Either<Failure, PaymentOrder>> getOrder(
    String orderId, {
    RequestCancelToken? cancelToken,
  }) async =>
      Right(_order(id: orderId));

  @override
  Future<Either<Failure, String>> downloadOrderPdf(
    String orderId, {
    RequestCancelToken? cancelToken,
  }) async =>
      const Right('/tmp/order.pdf');

  @override
  Future<Either<Failure, PaymentOrder>> uploadProof({
    required String orderId,
    required String filePath,
    required String fileName,
    required String mimeType,
  }) async =>
      Right(_order(id: orderId));

  @override
  Future<Either<Failure, PaymentOrder>> cancelOrder(String orderId) async =>
      Right(_order(id: orderId));

  @override
  Future<Either<Failure, InsuranceReassignment>> createReassignment({
    required int insuranceAssignmentId,
    required String toUserId,
    String? reason,
  }) async =>
      Right(
        InsuranceReassignment(
          requestId: 1,
          insuranceAssignmentId: insuranceAssignmentId,
          fromUserId: 'user-a',
          toUserId: toUserId,
          reason: reason,
          status: 'PENDING',
          rejectReason: null,
          createdAt: DateTime.utc(2026, 8, 12),
        ),
      );

  @override
  Future<Either<Failure, List<InsuranceReassignment>>> listReassignments({
    String? status,
    RequestCancelToken? cancelToken,
  }) async =>
      const Right([]);
}

void main() {
  late _FakeRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = _FakeRepository();
    container = ProviderContainer(
      overrides: [
        paymentOrdersRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
  });

  group('IssueOrderNotifier', () {
    test('toggle agrega y quita beneficiarios', () {
      final notifier = container.read(issueOrderNotifierProvider.notifier);

      notifier.toggle('user-1');
      notifier.toggle('user-2');
      expect(
        container.read(issueOrderNotifierProvider).selectedUserIds,
        {'user-1', 'user-2'},
      );

      notifier.toggle('user-1');
      expect(
        container.read(issueOrderNotifierProvider).selectedUserIds,
        {'user-2'},
      );
    });

    test('no emite sin beneficiarios seleccionados', () async {
      final notifier = container.read(issueOrderNotifierProvider.notifier);

      final order = await notifier.submitInsurance(cycleConfigId: 3);

      expect(order, isNull);
      expect(repository.createInsuranceCalls, 0);
    });

    test('emite orden de seguro con ciclo y beneficiarios', () async {
      final notifier = container.read(issueOrderNotifierProvider.notifier);
      notifier.toggle('user-1');
      notifier.toggle('user-2');

      final order = await notifier.submitInsurance(cycleConfigId: 3);

      expect(order?.orderId, 'order-1');
      expect(repository.createInsuranceCalls, 1);
      expect(repository.lastCycleConfigId, 3);
      expect(
        repository.lastBeneficiaries,
        unorderedEquals(['user-1', 'user-2']),
      );
      expect(
        container.read(issueOrderNotifierProvider).issuedOrder?.orderId,
        'order-1',
      );
    });

    test('emite orden de camporee con el id correcto', () async {
      final notifier = container.read(issueOrderNotifierProvider.notifier);
      notifier.toggle('user-1');

      await notifier.submitCamporee(camporeeId: 12);

      expect(repository.createCamporeeCalls, 1);
      expect(repository.lastCamporeeId, 12);
      expect(repository.lastCamporeeType, 'local');
    });

    test('emite orden de camporee de unión con el tipo correcto', () async {
      final notifier = container.read(issueOrderNotifierProvider.notifier);
      notifier.toggle('user-1');

      await notifier.submitCamporee(camporeeId: 90, camporeeType: 'union');

      expect(repository.createCamporeeCalls, 1);
      expect(repository.lastCamporeeId, 90);
      expect(repository.lastCamporeeType, 'union');
    });

    test('el fallo del repositorio queda en errorMessage', () async {
      repository.createResult =
          const Left(ServerFailure(message: 'Cupo excedido'));
      final notifier = container.read(issueOrderNotifierProvider.notifier);
      notifier.toggle('user-1');

      final order = await notifier.submitInsurance(cycleConfigId: 3);

      expect(order, isNull);
      final state = container.read(issueOrderNotifierProvider);
      expect(state.errorMessage, 'Cupo excedido');
      expect(state.isSubmitting, isFalse);
    });
  });

  group('OrderActionsNotifier', () {
    test('cancelOrder regresa true y limpia el estado', () async {
      final notifier = container.read(orderActionsNotifierProvider.notifier);

      final ok = await notifier.cancelOrder('order-1');

      expect(ok, isTrue);
      expect(
        container.read(orderActionsNotifierProvider).isWorking,
        isFalse,
      );
    });
  });
}
