import 'package:dartz/dartz.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/insurance/domain/entities/insurance_overview.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:sacdia_app/features/payment_orders/domain/entities/payment_order.dart';
import 'package:sacdia_app/features/payment_orders/domain/repositories/payment_orders_repository.dart';

const testClubContext = ClubContext(
  clubId: 1,
  sectionId: 10,
  clubTypeName: 'Conquistadores',
);

const testYear = InsuranceYear(id: 9, label: '2027');

InsuranceCycle testCycle() => InsuranceCycle(
      cycleConfigId: 4,
      unitCostCentavos: 35000,
      purchaseDeadline: DateTime(2027, 2, 28),
    );

InsurancePerson uninsuredPerson(
  String id,
  String name, {
  String role = 'Amigo',
  bool staff = false,
}) =>
    InsurancePerson(
      userId: id,
      name: name,
      roleLabel: role,
      isStaff: staff,
      status: InsurancePersonStatus.uninsured,
    );

/// The scenario of the mockup: 12 people on 14 Feb 2027.
InsuranceOverview mockupOverview() => InsuranceOverview(
      year: testYear,
      cycle: testCycle(),
      counts: const InsuranceCounts(
        total: 12,
        covered: 4,
        inProcess: 4,
        uninsured: 3,
      ),
      freeCoveragesCount: 1,
      people: [
        uninsuredPerson('u-1', 'Diego Campos'),
        uninsuredPerson('u-2', 'Valeria Ríos', role: 'Compañero'),
        uninsuredPerson('u-3', 'Mateo Herrera', role: 'counselor', staff: true),
        InsurancePerson(
          userId: 'u-4',
          name: 'Sofía Navarro',
          roleLabel: 'Explorador',
          status: InsurancePersonStatus.proofRejected,
          activeOrder: InsuranceActiveOrder(
            orderId: 'o-41',
            folio: 'ORD20270041',
            status: PaymentOrderStatus.proofRejected,
            expiresAt: DateTime(2027, 2, 21),
          ),
        ),
        InsurancePerson(
          userId: 'u-5',
          name: 'Tomás Aguilar',
          roleLabel: 'Amigo',
          status: InsurancePersonStatus.inOrder,
          activeOrder: InsuranceActiveOrder(
            orderId: 'o-44',
            folio: 'ORD20270044',
            status: PaymentOrderStatus.issued,
            expiresAt: DateTime(2027, 2, 21),
          ),
        ),
        InsurancePerson(
          userId: 'u-6',
          name: 'Renata Ochoa',
          roleLabel: 'Pionero',
          status: InsurancePersonStatus.inOrder,
          activeOrder: InsuranceActiveOrder(
            orderId: 'o-44',
            folio: 'ORD20270044',
            status: PaymentOrderStatus.issued,
            expiresAt: DateTime(2027, 2, 21),
          ),
        ),
        InsurancePerson(
          userId: 'u-7',
          name: 'Emiliano Paz',
          roleLabel: 'Excursionista',
          status: InsurancePersonStatus.inReview,
          activeOrder: InsuranceActiveOrder(
            orderId: 'o-39',
            folio: 'ORD20270039',
            status: PaymentOrderStatus.proofSubmitted,
          ),
        ),
        const InsurancePerson(
          userId: 'u-8',
          name: 'Lucía Medina',
          roleLabel: 'Guía',
          status: InsurancePersonStatus.covered,
          coverage: InsuranceCoverage(
            source: CoverageSource.paidElsewhere,
            paidInSectionName: 'Guías Mayores',
            paidInClubName: 'Club Orión',
            orderFolio: 'ORD20270012',
          ),
        ),
        const InsurancePerson(
          userId: 'u-9',
          name: 'Joaquín Salas',
          roleLabel: 'Pionero',
          status: InsurancePersonStatus.covered,
          coverage: InsuranceCoverage(
            source: CoverageSource.reassigned,
            reassignedFromName: 'Ximena Lara',
          ),
        ),
        const InsurancePerson(
          userId: 'u-10',
          name: 'Andrés Vidal',
          roleLabel: 'Explorador',
          status: InsurancePersonStatus.covered,
          coverage: InsuranceCoverage(
            source: CoverageSource.paidHere,
            orderFolio: 'ORD20270031',
          ),
        ),
        const InsurancePerson(
          userId: 'u-11',
          name: 'Camila Torres',
          roleLabel: 'Compañero',
          status: InsurancePersonStatus.covered,
          coverage: InsuranceCoverage(
            source: CoverageSource.paidHere,
            orderFolio: 'ORD20270031',
          ),
        ),
        const InsurancePerson(
          userId: 'u-12',
          name: 'Natalia Rojas',
          roleLabel: 'director',
          isStaff: true,
          status: InsurancePersonStatus.covered,
          coverage: InsuranceCoverage(
            source: CoverageSource.paidHere,
            orderFolio: 'ORD20270031',
          ),
        ),
      ],
    );

PaymentOrder testOrder() => PaymentOrder(
      orderId: 'order-1',
      purpose: PaymentOrderPurpose.insurance,
      folioReference: 'ORD20270045',
      currency: 'MXN',
      unitCostCentavos: 35000,
      totalCentavos: 70000,
      status: PaymentOrderStatus.issued,
      expiresAt: DateTime.utc(2027, 2, 28),
      createdAt: DateTime.utc(2027, 2, 14),
    );

class FakePaymentOrdersRepo implements PaymentOrdersRepository {
  Either<Failure, PaymentOrder> createResult = Right(testOrder());
  Either<Failure, InsuranceReassignment>? reassignResult;
  final keys = <String?>[];
  final sentIds = <List<String>>[];
  int reassignCalls = 0;
  ({int assignmentId, String to})? lastReassign;

  @override
  Future<Either<Failure, PaymentOrder>> createInsuranceOrder({
    required int cycleConfigId,
    required List<String> beneficiaryUserIds,
    String? idempotencyKey,
  }) async {
    keys.add(idempotencyKey);
    sentIds.add(beneficiaryUserIds);
    return createResult;
  }

  @override
  Future<Either<Failure, InsuranceReassignment>> createReassignment({
    required int insuranceAssignmentId,
    required String toUserId,
    String? reason,
  }) async {
    reassignCalls++;
    lastReassign = (assignmentId: insuranceAssignmentId, to: toUserId);
    return reassignResult ??
        Right(
          InsuranceReassignment(
            requestId: 1,
            insuranceAssignmentId: insuranceAssignmentId,
            fromUserId: 'a',
            toUserId: toUserId,
            status: 'APPROVED',
            createdAt: DateTime.utc(2027, 2, 6),
          ),
        );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
