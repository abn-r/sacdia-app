import 'package:equatable/equatable.dart';
import '../../domain/entities/monthly_report.dart';

int? _intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double _doubleValue(dynamic value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

bool? _boolValue(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().toLowerCase();
  if (text == 'true') return true;
  if (text == 'false') return false;
  return null;
}

DateTime? _dateValue(dynamic value) {
  if (value is DateTime) return value;
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

Map<String, dynamic> _mapValue(dynamic value) =>
    value is Map<String, dynamic> ? value : const <String, dynamic>{};

List<Map<String, dynamic>> _mapList(dynamic value) => value is List
    ? value.whereType<Map<String, dynamic>>().toList(growable: false)
    : const [];

String? _stringValue(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

MonthlyReportSnapshot? _parseSnapshot(dynamic raw) {
  final json = _mapValue(raw);
  if (json.isEmpty) return null;

  final honors = _mapValue(json['honors']);
  final activities = _mapValue(json['activities']);
  final finances = _mapValue(json['finances']);

  return MonthlyReportSnapshot(
    memberCount: _intValue(json['member_count']),
    meetingDays: _stringValue(json['meeting_days']),
    directiva: _mapList(json['directiva'])
        .map((item) => MonthlyReportLeader(
              name: _stringValue(item['name']) ?? '—',
              role: _stringValue(item['role']) ?? '—',
            ))
        .toList(growable: false),
    honors: MonthlyReportHonorsSummary(
      started: _intValue(honors['started']) ?? 0,
      completed: _intValue(honors['completed']) ?? 0,
      items: _mapList(honors['items'])
          .map((item) => MonthlyReportHonorItem(
                name: _stringValue(item['name']) ?? '—',
                status: _stringValue(item['status']),
              ))
          .toList(growable: false),
    ),
    activities: MonthlyReportActivitiesSummary(
      total: _intValue(activities['total']) ?? 0,
      items: _mapList(activities['items'])
          .map((item) => MonthlyReportActivityItem(
                name: _stringValue(item['name']) ?? '—',
                date: _dateValue(item['date']),
                type: _stringValue(item['type']),
                attendees: _intValue(item['attendees']),
              ))
          .toList(growable: false),
    ),
    finances: MonthlyReportFinancesSummary(
      income: _doubleValue(finances['income']),
      expenses: _doubleValue(finances['expenses']),
      balance: _doubleValue(finances['balance']),
      totalBalance: finances.containsKey('total_balance')
          ? _doubleValue(finances['total_balance'])
          : null,
      transactions: _intValue(finances['transactions']) ?? 0,
    ),
  );
}

MonthlyReportManualData? _parseManualData(dynamic raw) {
  final json = _mapValue(raw);
  if (json.isEmpty) return null;

  return MonthlyReportManualData(
    planningMeetings: _intValue(json['planning_meetings']),
    parentMeetings: _intValue(json['parent_meetings']),
    youthCouncilAttendance: _intValue(json['youth_council_attendance']),
    churchBoardAttendance: _intValue(json['church_board_attendance']),
    soulTarget: _intValue(json['soul_target']),
    unbaptizedMembers: _intValue(json['unbaptized_members']),
    bibleStudiesReceiving: _intValue(json['bible_studies_receiving']),
    hasWeeklyBibleInstruction: _boolValue(json['has_weekly_bible_instruction']),
    bibleStudiesGiven: _boolValue(json['bible_studies_given']),
    literatureDistributed: _boolValue(json['literature_distributed']),
    baptizedThisMonth: _intValue(json['baptized_this_month']),
    totalBaptized: _intValue(json['total_baptized']),
    clubParticipationDescription:
        _stringValue(json['club_participation_description']),
    communityServiceDescription:
        _stringValue(json['community_service_description']),
    certificatesDelivered: _boolValue(json['certificates_delivered']),
    membersHaveBooklet: _boolValue(json['members_have_booklet']),
    bookletRequirementsSigned: _boolValue(json['booklet_requirements_signed']),
  );
}

/// Modelo de informe mensual para la capa de datos
class MonthlyReportModel extends Equatable {
  final String id;
  final String enrollmentId;
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
  final String? clubName;
  final String? clubType;
  final MonthlyReportSnapshot? snapshot;
  final MonthlyReportManualData? manualData;
  final DateTime? generatedAt;
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
    this.clubName,
    this.clubType,
    this.snapshot,
    this.manualData,
    this.generatedAt,
    this.submittedAt,
    this.createdAt,
  });

  factory MonthlyReportModel.fromJson(Map<String, dynamic> json) {
    final snapshot = _parseSnapshot(json['snapshot_data']);
    final manual = _parseManualData(json['manual_data']);
    final clubEnrollment = _mapValue(json['club_enrollment']);
    final clubSection = _mapValue(clubEnrollment['club_section']);
    final club = _mapValue(clubSection['clubs']);
    final clubType = _mapValue(clubSection['club_types']);

    return MonthlyReportModel(
      id: (json['id'] ?? json['report_id'] ?? json['monthly_report_id'])
              ?.toString() ??
          '',
      enrollmentId:
          (json['enrollment_id'] ?? json['club_enrollment_id'])?.toString() ??
              '',
      month: _intValue(json['month']) ?? 0,
      year: _intValue(json['year']) ?? DateTime.now().year,
      status: json['status'] as String? ?? 'draft',
      totalActivities:
          _intValue(json['total_activities']) ?? snapshot?.activities.total,
      totalAttendance: _intValue(json['total_attendance']),
      totalMembers: _intValue(json['total_members']) ?? snapshot?.memberCount,
      attendanceRate: json['attendance_rate'] != null
          ? _doubleValue(json['attendance_rate'])
          : null,
      newMembers: _intValue(json['new_members']),
      droppedMembers: _intValue(json['dropped_members']),
      notes: _stringValue(json['notes']) ??
          manual?.clubParticipationDescription ??
          manual?.communityServiceDescription,
      clubName: _stringValue(json['club_name']) ?? _stringValue(club['name']),
      clubType:
          _stringValue(json['club_type']) ?? _stringValue(clubType['name']),
      snapshot: snapshot,
      manualData: manual,
      generatedAt: _dateValue(json['generated_at']),
      submittedAt: _dateValue(json['submitted_at']),
      createdAt: _dateValue(json['created_at']),
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
      clubName: clubName,
      clubType: clubType,
      snapshot: snapshot,
      manualData: manualData,
      generatedAt: generatedAt,
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
        clubName,
        clubType,
        snapshot,
        manualData,
        generatedAt,
        submittedAt,
        createdAt,
      ];
}

/// Modelo de preview del informe mensual
class MonthlyReportPreviewModel extends Equatable {
  final String enrollmentId;
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
    final activities = json['activities'] is Map<String, dynamic>
        ? json['activities'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return MonthlyReportPreviewModel(
      enrollmentId:
          (json['enrollment_id'] ?? json['club_enrollment_id'])?.toString() ??
              '',
      month: _intValue(json['month']) ?? 0,
      year: _intValue(json['year']) ?? DateTime.now().year,
      totalActivities: _intValue(json['total_activities']) ??
          _intValue(activities['total']) ??
          0,
      totalAttendance: _intValue(json['total_attendance']) ?? 0,
      totalMembers: _intValue(json['total_members']) ?? 0,
      attendanceRate: json['attendance_rate'] != null
          ? _doubleValue(json['attendance_rate'])
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

class VisibleMonthlyReportModel extends Equatable {
  final String id;
  final String enrollmentId;
  final int month;
  final int year;
  final String status;
  final DateTime? generatedAt;
  final DateTime? submittedAt;
  final String? clubName;
  final String? clubType;
  final String? localField;
  final String? submitterName;
  final int? memberCount;

  const VisibleMonthlyReportModel({
    required this.id,
    required this.enrollmentId,
    required this.month,
    required this.year,
    required this.status,
    this.generatedAt,
    this.submittedAt,
    this.clubName,
    this.clubType,
    this.localField,
    this.submitterName,
    this.memberCount,
  });

  factory VisibleMonthlyReportModel.fromJson(Map<String, dynamic> json) {
    return VisibleMonthlyReportModel(
      id: (json['monthly_report_id'] ?? json['report_id'] ?? json['id'])
              ?.toString() ??
          '',
      enrollmentId:
          (json['club_enrollment_id'] ?? json['enrollment_id'])?.toString() ??
              '',
      month: _intValue(json['month']) ?? 0,
      year: _intValue(json['year']) ?? DateTime.now().year,
      status: json['status'] as String? ?? 'draft',
      generatedAt: _dateValue(json['generated_at']),
      submittedAt: _dateValue(json['submitted_at']),
      clubName: json['club_name'] as String?,
      clubType: json['club_type'] as String?,
      localField: json['local_field'] as String?,
      submitterName: json['submitter_name'] as String?,
      memberCount: _intValue(json['member_count']),
    );
  }

  VisibleMonthlyReport toEntity() {
    return VisibleMonthlyReport(
      id: id,
      enrollmentId: enrollmentId,
      month: month,
      year: year,
      status: status,
      generatedAt: generatedAt,
      submittedAt: submittedAt,
      clubName: clubName,
      clubType: clubType,
      localField: localField,
      submitterName: submitterName,
      memberCount: memberCount,
    );
  }

  @override
  List<Object?> get props => [
        id,
        enrollmentId,
        month,
        year,
        status,
        generatedAt,
        submittedAt,
        clubName,
        clubType,
        localField,
        submitterName,
        memberCount,
      ];
}

class VisibleMonthlyReportsPageModel extends Equatable {
  final int total;
  final int page;
  final int limit;
  final List<VisibleMonthlyReportModel> items;

  const VisibleMonthlyReportsPageModel({
    required this.total,
    required this.page,
    required this.limit,
    required this.items,
  });

  factory VisibleMonthlyReportsPageModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return VisibleMonthlyReportsPageModel(
      total: _intValue(json['total']) ?? 0,
      page: _intValue(json['page']) ?? 1,
      limit: _intValue(json['limit']) ?? 25,
      items: rawItems is List
          ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(VisibleMonthlyReportModel.fromJson)
              .toList()
          : const [],
    );
  }

  VisibleMonthlyReportsPage toEntity() {
    return VisibleMonthlyReportsPage(
      total: total,
      page: page,
      limit: limit,
      items: items.map((item) => item.toEntity()).toList(),
    );
  }

  @override
  List<Object?> get props => [total, page, limit, items];
}
