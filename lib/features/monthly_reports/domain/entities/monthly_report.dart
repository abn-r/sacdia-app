import 'package:equatable/equatable.dart';

/// Estado del informe mensual
enum MonthlyReportStatus { draft, submitted, approved, rejected }

extension MonthlyReportStatusX on MonthlyReportStatus {
  String get label {
    switch (this) {
      case MonthlyReportStatus.draft:
        return 'Borrador';
      case MonthlyReportStatus.submitted:
        return 'Enviado';
      case MonthlyReportStatus.approved:
        return 'Aprobado';
      case MonthlyReportStatus.rejected:
        return 'Rechazado';
    }
  }
}

/// Entidad de informe mensual
class MonthlyReport extends Equatable {
  final int id;
  final int enrollmentId;
  final int month;
  final int year;
  final String status;

  // Datos automáticos (calculados por el sistema)
  final int? totalActivities;
  final int? totalAttendance;
  final int? totalMembers;
  final double? attendanceRate;

  // Datos manuales
  final int? newMembers;
  final int? droppedMembers;
  final String? notes;

  final DateTime? submittedAt;
  final DateTime? createdAt;

  const MonthlyReport({
    required this.id,
    required this.enrollmentId,
    required this.month,
    required this.year,
    required this.status,
    this.totalActivities,
    this.totalAttendance,
    this.totalMembers,
    this.attendanceRate,
    this.newMembers,
    this.droppedMembers,
    this.notes,
    this.submittedAt,
    this.createdAt,
  });

  MonthlyReportStatus get reportStatus {
    switch (status) {
      case 'submitted':
        return MonthlyReportStatus.submitted;
      case 'approved':
        return MonthlyReportStatus.approved;
      case 'rejected':
        return MonthlyReportStatus.rejected;
      default:
        return MonthlyReportStatus.draft;
    }
  }

  String get monthName {
    const months = [
      '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    if (month >= 1 && month <= 12) return months[month];
    return 'Mes $month';
  }

  @override
  List<Object?> get props => [
        id,
        enrollmentId,
        month,
        year,
        status,
        totalActivities,
        totalAttendance,
        totalMembers,
        attendanceRate,
        newMembers,
        droppedMembers,
        notes,
        submittedAt,
        createdAt,
      ];
}

/// Preview de un informe mensual (datos calculados antes de guardar)
class MonthlyReportPreview extends Equatable {
  final int enrollmentId;
  final int month;
  final int year;
  final int totalActivities;
  final int totalAttendance;
  final int totalMembers;
  final double attendanceRate;

  const MonthlyReportPreview({
    required this.enrollmentId,
    required this.month,
    required this.year,
    required this.totalActivities,
    required this.totalAttendance,
    required this.totalMembers,
    required this.attendanceRate,
  });

  @override
  List<Object?> get props => [
        enrollmentId,
        month,
        year,
        totalActivities,
        totalAttendance,
        totalMembers,
        attendanceRate,
      ];
}
