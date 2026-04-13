import 'package:equatable/equatable.dart';
import '../../domain/entities/monthly_report.dart';

/// Modelo de informe mensual para la capa de datos
class MonthlyReportModel extends Equatable {
  final int id;
  final int enrollmentId;
  final int month;
  final int year;
  final String status;
  final int? totalActivities;
  final int? totalAttendance;
  final int? totalMembers;
  final double? attendanceRate;
  final int? newMembers;
  final int? droppedMembers;
  final String? notes;
  final DateTime? submittedAt;
  final DateTime? createdAt;

  const MonthlyReportModel({
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

  factory MonthlyReportModel.fromJson(Map<String, dynamic> json) {
    return MonthlyReportModel(
      id: (json['id'] ?? json['report_id']) as int,
      enrollmentId: json['enrollment_id'] as int? ?? 0,
      month: json['month'] as int? ?? 0,
      year: json['year'] as int? ?? DateTime.now().year,
      status: json['status'] as String? ?? 'draft',
      totalActivities: json['total_activities'] as int?,
      totalAttendance: json['total_attendance'] as int?,
      totalMembers: json['total_members'] as int?,
      attendanceRate: json['attendance_rate'] != null
          ? (json['attendance_rate'] as num).toDouble()
          : null,
      newMembers: json['new_members'] as int?,
      droppedMembers: json['dropped_members'] as int?,
      notes: json['notes'] as String?,
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  MonthlyReport toEntity() {
    return MonthlyReport(
      id: id,
      enrollmentId: enrollmentId,
      month: month,
      year: year,
      status: status,
      totalActivities: totalActivities,
      totalAttendance: totalAttendance,
      totalMembers: totalMembers,
      attendanceRate: attendanceRate,
      newMembers: newMembers,
      droppedMembers: droppedMembers,
      notes: notes,
      submittedAt: submittedAt,
      createdAt: createdAt,
    );
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

/// Modelo de preview del informe mensual
class MonthlyReportPreviewModel extends Equatable {
  final int enrollmentId;
  final int month;
  final int year;
  final int totalActivities;
  final int totalAttendance;
  final int totalMembers;
  final double attendanceRate;

  const MonthlyReportPreviewModel({
    required this.enrollmentId,
    required this.month,
    required this.year,
    required this.totalActivities,
    required this.totalAttendance,
    required this.totalMembers,
    required this.attendanceRate,
  });

  factory MonthlyReportPreviewModel.fromJson(Map<String, dynamic> json) {
    return MonthlyReportPreviewModel(
      enrollmentId: json['enrollment_id'] as int? ?? 0,
      month: json['month'] as int? ?? 0,
      year: json['year'] as int? ?? DateTime.now().year,
      totalActivities: json['total_activities'] as int? ?? 0,
      totalAttendance: json['total_attendance'] as int? ?? 0,
      totalMembers: json['total_members'] as int? ?? 0,
      attendanceRate: json['attendance_rate'] != null
          ? (json['attendance_rate'] as num).toDouble()
          : 0.0,
    );
  }

  MonthlyReportPreview toEntity() {
    return MonthlyReportPreview(
      enrollmentId: enrollmentId,
      month: month,
      year: year,
      totalActivities: totalActivities,
      totalAttendance: totalAttendance,
      totalMembers: totalMembers,
      attendanceRate: attendanceRate,
    );
  }

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
