import 'package:equatable/equatable.dart';

import '../../../payment_orders/domain/entities/payment_order.dart';

/// Where one person stands for the ecclesiastical year.
///
/// The server decides it; the app never derives it from dates.
enum InsurancePersonStatus {
  covered,
  inOrder,
  inReview,
  proofRejected,
  uninsured;

  /// Unknown values fall back to [uninsured]: the issue request is then
  /// validated by the server, which answers 409 if the person is not free.
  static InsurancePersonStatus fromApi(String? value) => switch (value) {
        'covered' => InsurancePersonStatus.covered,
        'in_order' => InsurancePersonStatus.inOrder,
        'in_review' => InsurancePersonStatus.inReview,
        'proof_rejected' => InsurancePersonStatus.proofRejected,
        _ => InsurancePersonStatus.uninsured,
      };

  /// Part of an order that is still moving (issued, in review or rejected).
  bool get inProcess =>
      this == InsurancePersonStatus.inOrder ||
      this == InsurancePersonStatus.inReview ||
      this == InsurancePersonStatus.proofRejected;
}

/// How a person got covered.
enum CoverageSource {
  paidHere,
  paidElsewhere,
  reassigned;

  static CoverageSource fromApi(String? value) => switch (value) {
        'paid_elsewhere' => CoverageSource.paidElsewhere,
        'reassigned' => CoverageSource.reassigned,
        _ => CoverageSource.paidHere,
      };
}

/// Ecclesiastical year the insurance covers.
class InsuranceYear extends Equatable {
  const InsuranceYear({
    required this.id,
    required this.label,
    this.startDate,
    this.endDate,
  });

  final int id;
  final String label;
  final DateTime? startDate;
  final DateTime? endDate;

  @override
  List<Object?> get props => [id, label, startDate, endDate];
}

/// Cost the local field published for the year. Null in the overview when it
/// has not published one.
class InsuranceCycle extends Equatable {
  const InsuranceCycle({
    required this.cycleConfigId,
    required this.unitCostCentavos,
    this.purchaseDeadline,
    this.currency = 'MXN',
  });

  final int cycleConfigId;
  final int unitCostCentavos;
  final DateTime? purchaseDeadline;
  final String currency;

  @override
  List<Object?> get props =>
      [cycleConfigId, unitCostCentavos, purchaseDeadline, currency];
}

class InsuranceCounts extends Equatable {
  const InsuranceCounts({
    this.total = 0,
    this.covered = 0,
    this.inProcess = 0,
    this.uninsured = 0,
  });

  final int total;
  final int covered;
  final int inProcess;
  final int uninsured;

  @override
  List<Object?> get props => [total, covered, inProcess, uninsured];
}

/// The year's coverage of a person: where it was paid or who it came from.
class InsuranceCoverage extends Equatable {
  const InsuranceCoverage({
    required this.source,
    this.paidInSectionName,
    this.paidInClubName,
    this.orderFolio,
    this.approvedAt,
    this.validUntil,
    this.reassignedFromName,
    this.reassignedByName,
    this.reassignedAt,
  });

  final CoverageSource source;
  final String? paidInSectionName;
  final String? paidInClubName;
  final String? orderFolio;
  final DateTime? approvedAt;
  final DateTime? validUntil;
  final String? reassignedFromName;
  final String? reassignedByName;
  final DateTime? reassignedAt;

  @override
  List<Object?> get props => [
        source,
        paidInSectionName,
        paidInClubName,
        orderFolio,
        approvedAt,
        validUntil,
        reassignedFromName,
        reassignedByName,
        reassignedAt,
      ];
}

/// The open order a person is in.
class InsuranceActiveOrder extends Equatable {
  const InsuranceActiveOrder({
    required this.orderId,
    required this.folio,
    required this.status,
    this.expiresAt,
  });

  final String orderId;
  final String folio;
  final PaymentOrderStatus status;
  final DateTime? expiresAt;

  @override
  List<Object?> get props => [orderId, folio, status, expiresAt];
}

/// A member or board member of the section with the year's insurance state.
class InsurancePerson extends Equatable {
  const InsurancePerson({
    required this.userId,
    required this.name,
    required this.status,
    this.picture,
    this.roleLabel,
    this.isStaff = false,
    this.coverage,
    this.activeOrder,
  });

  final String userId;
  final String name;
  final String? picture;

  /// A class name for members; the raw role name (`counselor`) for staff.
  final String? roleLabel;
  final bool isStaff;
  final InsurancePersonStatus status;
  final InsuranceCoverage? coverage;
  final InsuranceActiveOrder? activeOrder;

  @override
  List<Object?> get props => [
        userId,
        name,
        picture,
        roleLabel,
        isStaff,
        status,
        coverage,
        activeOrder
      ];
}

/// An open order of the section and the people it holds, for "To attend".
class InsuranceOrderSummary extends Equatable {
  const InsuranceOrderSummary({
    required this.order,
    required this.peopleCount,
  });

  final InsuranceActiveOrder order;
  final int peopleCount;

  @override
  List<Object?> get props => [order, peopleCount];
}

/// `GET club-sections/:id/insurance/overview`.
class InsuranceOverview extends Equatable {
  const InsuranceOverview({
    required this.year,
    required this.cycle,
    required this.counts,
    required this.freeCoveragesCount,
    required this.people,
  });

  final InsuranceYear? year;
  final InsuranceCycle? cycle;
  final InsuranceCounts counts;
  final int freeCoveragesCount;
  final List<InsurancePerson> people;

  List<InsurancePerson> get uninsured => people
      .where((p) => p.status == InsurancePersonStatus.uninsured)
      .toList(growable: false);

  /// People that cannot go in a new order: already in one or covered.
  List<InsurancePerson> get blocked => people
      .where((p) => p.status != InsurancePersonStatus.uninsured)
      .toList(growable: false);

  /// Open orders grouped from the people's `active_order`, in order of
  /// appearance.
  List<InsuranceOrderSummary> get openOrders {
    final order = <String, InsuranceActiveOrder>{};
    final counts = <String, int>{};
    for (final p in people) {
      final o = p.activeOrder;
      if (o == null) continue;
      order.putIfAbsent(o.orderId, () => o);
      counts[o.orderId] = (counts[o.orderId] ?? 0) + 1;
    }
    return [
      for (final e in order.entries)
        InsuranceOrderSummary(order: e.value, peopleCount: counts[e.key]!),
    ];
  }

  /// Orders whose receipt was rejected: the director must upload another.
  List<InsuranceOrderSummary> get rejectedOrders => openOrders
      .where((o) => o.order.status == PaymentOrderStatus.proofRejected)
      .toList(growable: false);

  /// Issued orders still waiting for the receipt.
  List<InsuranceOrderSummary> get ordersNeedingReceipt => openOrders
      .where((o) => o.order.status == PaymentOrderStatus.issued)
      .toList(growable: false);

  InsurancePerson? personById(String userId) {
    for (final p in people) {
      if (p.userId == userId) return p;
    }
    return null;
  }

  /// The year has started and nobody is insured yet.
  /// Nobody covered yet AND the ecclesiastical year began recently (first
  /// [yearStartWindowDays] days). Late in the year the regular list is shown:
  /// "the year just started" would be false there.
  bool isYearStart([DateTime? today]) {
    final start = year?.startDate;
    if (start == null) return false;
    final now = today ?? DateTime.now();
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(start.year, start.month, start.day))
        .inDays;
    return days >= 0 &&
        days <= yearStartWindowDays &&
        counts.total > 0 &&
        counts.covered == 0 &&
        counts.inProcess == 0 &&
        counts.uninsured == counts.total;
  }

  static const yearStartWindowDays = 60;

  bool get isAllCovered => counts.total > 0 && counts.covered == counts.total;

  @override
  List<Object?> get props => [year, cycle, counts, freeCoveragesCount, people];
}

/// A covered person whose holder left the club: the director can pass it on.
class FreeCoverage extends Equatable {
  const FreeCoverage({
    required this.assignmentId,
    required this.holderUserId,
    required this.holderName,
    this.validUntil,
    this.orderId,
    this.orderFolio,
    this.leftAt,
  });

  final int assignmentId;
  final String holderUserId;
  final String holderName;
  final DateTime? validUntil;
  final String? orderId;
  final String? orderFolio;
  final DateTime? leftAt;

  @override
  List<Object?> get props => [
        assignmentId,
        holderUserId,
        holderName,
        validUntil,
        orderId,
        orderFolio,
        leftAt,
      ];
}
