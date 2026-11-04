import 'package:equatable/equatable.dart';

/// Tipos de pendiente que el cliente sabe pintar.
///
/// El servidor puede añadir tipos nuevos: los desconocidos se descartan al
/// parsear (ver `DashboardPendingModel`), nunca llegan a la UI.
enum PendingItemType {
  membershipRequests,
  evidenceFolder,
  monthlyReport,
  investitureAuthorizations,
}

/// Gravedad de un pendiente, de mayor a menor.
enum PendingSeverity { urgent, warning, info }

/// Estado del informe mensual cuando todavía está por entregar.
enum PendingReportStatus { missing, draft, generated, rejected }

/// Una fila de «Pendientes» (`GET /dashboard/pending`).
class PendingItem extends Equatable {
  const PendingItem({
    required this.type,
    required this.count,
    required this.severity,
    this.rejectedCount,
    this.notSubmittedCount,
    this.reportStatus,
    this.periodMonth,
    this.periodYear,
    this.dueDate,
    this.daysLeft,
  });

  final PendingItemType type;
  final int count;
  final PendingSeverity severity;

  /// Solo `evidence_folder`: secciones rechazadas.
  final int? rejectedCount;

  /// Solo `evidence_folder`: secciones sin enviar.
  final int? notSubmittedCount;

  /// Solo `monthly_report`.
  final PendingReportStatus? reportStatus;
  final int? periodMonth;
  final int? periodYear;
  final DateTime? dueDate;

  /// Solo `monthly_report`: días hasta el vencimiento (negativo si venció).
  final int? daysLeft;

  @override
  List<Object?> get props => [
        type,
        count,
        severity,
        rejectedCount,
        notSubmittedCount,
        reportStatus,
        periodMonth,
        periodYear,
        dueDate,
        daysLeft,
      ];
}

/// Resumen de pendientes de la sección activa.
class DashboardPending extends Equatable {
  const DashboardPending({
    this.sectionId,
    this.generatedAt,
    required this.total,
    required this.urgent,
    required this.items,
  });

  final int? sectionId;
  final DateTime? generatedAt;
  final int total;
  final int urgent;
  final List<PendingItem> items;

  bool get isEmpty => items.isEmpty;

  @override
  List<Object?> get props => [sectionId, generatedAt, total, urgent, items];
}
