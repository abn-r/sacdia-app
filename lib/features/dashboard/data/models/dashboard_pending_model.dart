import '../../domain/entities/dashboard_pending.dart';

/// Parser de `GET /dashboard/pending` (snake_case).
///
/// Tolerante: un `type` o `severity` desconocido descarta la fila (un servidor
/// más nuevo no rompe a un cliente viejo) y un campo mal tipado no tumba la
/// respuesta entera.
abstract final class DashboardPendingModel {
  static DashboardPending fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <PendingItem>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is! Map) continue;
        final item = _itemFromJson(Map<String, dynamic>.from(raw));
        if (item != null) items.add(item);
      }
    }

    return DashboardPending(
      sectionId: _int(json['section_id']),
      generatedAt: _date(json['generated_at']),
      total: _int(json['total']) ?? items.fold(0, (sum, i) => sum + i.count),
      urgent: _int(json['urgent']) ??
          items.where((i) => i.severity == PendingSeverity.urgent).length,
      items: items,
    );
  }

  static PendingItem? _itemFromJson(Map<String, dynamic> json) {
    final type = _type(json['type']);
    final severity = _severity(json['severity']);
    final count = _int(json['count']);
    if (type == null || severity == null || count == null || count <= 0) {
      return null;
    }

    return PendingItem(
      type: type,
      count: count,
      severity: severity,
      rejectedCount: _int(json['rejected_count']),
      notSubmittedCount: _int(json['not_submitted_count']),
      reportStatus: _reportStatus(json['report_status']),
      periodMonth: _int(json['period_month']),
      periodYear: _int(json['period_year']),
      dueDate: _date(json['due_date']),
      daysLeft: _int(json['days_left']),
    );
  }

  static PendingItemType? _type(Object? value) => switch (value) {
        'membership_requests' => PendingItemType.membershipRequests,
        'evidence_folder' => PendingItemType.evidenceFolder,
        'monthly_report' => PendingItemType.monthlyReport,
        'investiture_authorizations' =>
          PendingItemType.investitureAuthorizations,
        _ => null,
      };

  static PendingSeverity? _severity(Object? value) => switch (value) {
        'urgent' => PendingSeverity.urgent,
        'warning' => PendingSeverity.warning,
        'info' => PendingSeverity.info,
        _ => null,
      };

  static PendingReportStatus? _reportStatus(Object? value) => switch (value) {
        'missing' => PendingReportStatus.missing,
        'draft' => PendingReportStatus.draft,
        'generated' => PendingReportStatus.generated,
        'rejected' => PendingReportStatus.rejected,
        _ => null,
      };

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static DateTime? _date(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
