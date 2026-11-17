import '../../../payment_orders/domain/entities/payment_order.dart';
import '../../domain/entities/insurance_conflict.dart';
import '../../domain/entities/insurance_overview.dart';

/// Tolerant parsers for the insurance overview endpoints (snake_case).
///
/// A missing or badly typed field never throws: the screen degrades (no
/// cost, no date) instead of failing the whole response.
abstract final class InsuranceOverviewModel {
  static InsuranceOverview fromJson(Map<String, dynamic> json) {
    final peopleRaw = json['people'];
    return InsuranceOverview(
      year: _year(_map(json['year'])),
      cycle: _cycle(_map(json['cycle'])),
      counts: _counts(_map(json['counts'])),
      freeCoveragesCount: _int(json['free_coverages_count']) ?? 0,
      people: [
        if (peopleRaw is List)
          for (final raw in peopleRaw)
            if (raw is Map) _person(Map<String, dynamic>.from(raw)),
      ],
    );
  }

  static InsuranceYear? _year(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = _int(json['ecclesiastical_year_id']);
    if (id == null) return null;
    return InsuranceYear(
      id: id,
      label: json['label']?.toString() ?? '',
      startDate: _date(json['start_date']),
      endDate: _date(json['end_date']),
    );
  }

  static InsuranceCycle? _cycle(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = _int(json['insurance_cycle_config_id']);
    if (id == null) return null;
    return InsuranceCycle(
      cycleConfigId: id,
      unitCostCentavos: pesosToCentavos(json['unit_cost']),
      purchaseDeadline: _date(json['purchase_deadline']),
      currency: json['currency']?.toString() ?? 'MXN',
    );
  }

  static InsuranceCounts _counts(Map<String, dynamic>? json) {
    if (json == null) return const InsuranceCounts();
    return InsuranceCounts(
      total: _int(json['total']) ?? 0,
      covered: _int(json['covered']) ?? 0,
      inProcess: _int(json['in_process']) ?? 0,
      uninsured: _int(json['uninsured']) ?? 0,
    );
  }

  static InsurancePerson _person(Map<String, dynamic> json) {
    final coverage = _map(json['coverage']);
    final order = _map(json['active_order']);
    return InsurancePerson(
      userId: json['user_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      picture: _text(json['picture']),
      roleLabel: _text(json['role_label']),
      isStaff: json['is_staff'] == true,
      status: InsurancePersonStatus.fromApi(json['status']?.toString()),
      coverage: coverage == null ? null : _coverage(coverage),
      activeOrder: order == null ? null : _activeOrder(order),
    );
  }

  static InsuranceCoverage _coverage(Map<String, dynamic> json) {
    return InsuranceCoverage(
      source: CoverageSource.fromApi(json['source']?.toString()),
      paidInSectionName: _text(json['paid_in_section_name']),
      paidInClubName: _text(json['paid_in_club_name']),
      orderFolio: _text(json['order_folio']),
      approvedAt: _date(json['approved_at']),
      validUntil: _date(json['valid_until']),
      reassignedFromName: _text(json['reassigned_from_name']),
      reassignedByName: _text(json['reassigned_by_name']),
      reassignedAt: _date(json['reassigned_at']),
    );
  }

  static InsuranceActiveOrder _activeOrder(Map<String, dynamic> json) {
    return InsuranceActiveOrder(
      orderId: json['order_id']?.toString() ?? '',
      folio: json['folio']?.toString() ?? '',
      status: PaymentOrderStatusApi.fromApi(json['status']?.toString() ?? ''),
      expiresAt: _date(json['expires_at']),
    );
  }

  static List<FreeCoverage> freeCoveragesFromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    if (raw is! List) return const [];
    final result = <FreeCoverage>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final id = _int(map['insurance_assignment_id']);
      final holder = _map(map['holder']);
      if (id == null) continue;
      result.add(
        FreeCoverage(
          assignmentId: id,
          holderUserId: holder?['user_id']?.toString() ?? '',
          holderName: holder?['name']?.toString() ?? '',
          validUntil: _date(map['valid_until']),
          orderId: _text(map['order_id']),
          orderFolio: _text(map['order_folio']),
          leftAt: _date(map['left_at']),
        ),
      );
    }
    return result;
  }

  /// `data.conflicts` of the 409 body (also accepts a top-level `conflicts`).
  static List<InsuranceConflict> conflictsFromBody(Object? body) {
    if (body is! Map) return const [];
    final data = body['data'];
    final raw = (data is Map ? data['conflicts'] : null) ?? body['conflicts'];
    if (raw is! List) return const [];
    final result = <InsuranceConflict>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final status = _text(map['order_status']);
      result.add(
        InsuranceConflict(
          userId: map['user_id']?.toString() ?? '',
          name: map['name']?.toString() ?? '',
          reason: InsuranceConflictReason.fromApi(map['reason']?.toString()),
          sectionName: _text(map['section_name']),
          clubName: _text(map['club_name']),
          folio: _text(map['folio']),
          validUntil: _date(map['valid_until']),
          orderStatus:
              status == null ? null : PaymentOrderStatusApi.fromApi(status),
        ),
      );
    }
    return result;
  }

  /// "150.00" (or a number) in pesos to centavos.
  static int pesosToCentavos(Object? value) {
    final pesos = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    return (pesos * 100).round();
  }

  static Map<String, dynamic>? _map(Object? v) =>
      v is Map ? Map<String, dynamic>.from(v) : null;

  static String? _text(Object? v) {
    final s = v?.toString().trim();
    return s == null || s.isEmpty ? null : s;
  }

  static int? _int(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static DateTime? _date(Object? v) {
    if (v is! String || v.isEmpty) return null;
    return DateTime.tryParse(v);
  }
}
