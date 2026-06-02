import 'package:easy_localization/easy_localization.dart';
import 'package:equatable/equatable.dart';

/// Estado del informe mensual
enum MonthlyReportStatus { draft, generated, submitted, approved, rejected }

extension MonthlyReportStatusX on MonthlyReportStatus {
  String get label {
    switch (this) {
      case MonthlyReportStatus.draft:
        return tr('domain.statuses.draft');
      case MonthlyReportStatus.generated:
        return tr('domain.statuses.generated');
      case MonthlyReportStatus.submitted:
        return tr('domain.statuses.submitted');
      case MonthlyReportStatus.approved:
        return tr('domain.statuses.approved');
      case MonthlyReportStatus.rejected:
        return tr('domain.statuses.rejected');
    }
  }
}

class MonthlyReportLeader extends Equatable {
  final String name;
  final String role;

  const MonthlyReportLeader({required this.name, required this.role});

  @override
  List<Object?> get props => [name, role];
}

class MonthlyReportHonorItem extends Equatable {
  final String name;
  final String? status;

  const MonthlyReportHonorItem({required this.name, this.status});

  @override
  List<Object?> get props => [name, status];
}

class MonthlyReportHonorsSummary extends Equatable {
  final int started;
  final int completed;
  final List<MonthlyReportHonorItem> items;

  const MonthlyReportHonorsSummary({
    this.started = 0,
    this.completed = 0,
    this.items = const [],
  });

  @override
  List<Object?> get props => [started, completed, items];
}

class MonthlyReportActivityItem extends Equatable {
  final String name;
  final DateTime? date;
  final String? type;
  final int? attendees;

  const MonthlyReportActivityItem({
    required this.name,
    this.date,
    this.type,
    this.attendees,
  });

  @override
  List<Object?> get props => [name, date, type, attendees];
}

class MonthlyReportActivitiesSummary extends Equatable {
  final int total;
  final List<MonthlyReportActivityItem> items;

  const MonthlyReportActivitiesSummary({
    this.total = 0,
    this.items = const [],
  });

  @override
  List<Object?> get props => [total, items];
}

class MonthlyReportFinancesSummary extends Equatable {
  final double income;
  final double expenses;
  final double balance;
  final double? totalBalance;
  final int transactions;

  const MonthlyReportFinancesSummary({
    this.income = 0,
    this.expenses = 0,
    this.balance = 0,
    this.totalBalance,
    this.transactions = 0,
  });

  @override
  List<Object?> get props =>
      [income, expenses, balance, totalBalance, transactions];
}

class MonthlyReportSnapshot extends Equatable {
  final int? memberCount;
  final String? meetingDays;
  final List<MonthlyReportLeader> directiva;
  final MonthlyReportHonorsSummary honors;
  final MonthlyReportActivitiesSummary activities;
  final MonthlyReportFinancesSummary finances;

  const MonthlyReportSnapshot({
    this.memberCount,
    this.meetingDays,
    this.directiva = const [],
    this.honors = const MonthlyReportHonorsSummary(),
    this.activities = const MonthlyReportActivitiesSummary(),
    this.finances = const MonthlyReportFinancesSummary(),
  });

  @override
  List<Object?> get props => [
        memberCount,
        meetingDays,
        directiva,
        honors,
        activities,
        finances,
      ];
}

class MonthlyReportManualData extends Equatable {
  final int? planningMeetings;
  final int? parentMeetings;
  final int? youthCouncilAttendance;
  final int? churchBoardAttendance;
  final int? soulTarget;
  final int? unbaptizedMembers;
  final int? bibleStudiesReceiving;
  final bool? hasWeeklyBibleInstruction;
  final bool? bibleStudiesGiven;
  final bool? literatureDistributed;
  final int? baptizedThisMonth;
  final int? totalBaptized;
  final String? clubParticipationDescription;
  final String? communityServiceDescription;
  final bool? certificatesDelivered;
  final bool? membersHaveBooklet;
  final bool? bookletRequirementsSigned;

  const MonthlyReportManualData({
    this.planningMeetings,
    this.parentMeetings,
    this.youthCouncilAttendance,
    this.churchBoardAttendance,
    this.soulTarget,
    this.unbaptizedMembers,
    this.bibleStudiesReceiving,
    this.hasWeeklyBibleInstruction,
    this.bibleStudiesGiven,
    this.literatureDistributed,
    this.baptizedThisMonth,
    this.totalBaptized,
    this.clubParticipationDescription,
    this.communityServiceDescription,
    this.certificatesDelivered,
    this.membersHaveBooklet,
    this.bookletRequirementsSigned,
  });

  Map<String, dynamic> toJson() => {
        if (planningMeetings != null) 'planning_meetings': planningMeetings,
        if (parentMeetings != null) 'parent_meetings': parentMeetings,
        if (youthCouncilAttendance != null)
          'youth_council_attendance': youthCouncilAttendance,
        if (churchBoardAttendance != null)
          'church_board_attendance': churchBoardAttendance,
        if (soulTarget != null) 'soul_target': soulTarget,
        if (unbaptizedMembers != null) 'unbaptized_members': unbaptizedMembers,
        if (bibleStudiesReceiving != null)
          'bible_studies_receiving': bibleStudiesReceiving,
        if (hasWeeklyBibleInstruction != null)
          'has_weekly_bible_instruction': hasWeeklyBibleInstruction,
        if (bibleStudiesGiven != null) 'bible_studies_given': bibleStudiesGiven,
        if (literatureDistributed != null)
          'literature_distributed': literatureDistributed,
        if (baptizedThisMonth != null) 'baptized_this_month': baptizedThisMonth,
        if (totalBaptized != null) 'total_baptized': totalBaptized,
        'club_participation_description': clubParticipationDescription,
        'community_service_description': communityServiceDescription,
        if (certificatesDelivered != null)
          'certificates_delivered': certificatesDelivered,
        if (membersHaveBooklet != null)
          'members_have_booklet': membersHaveBooklet,
        if (bookletRequirementsSigned != null)
          'booklet_requirements_signed': bookletRequirementsSigned,
      };

  @override
  List<Object?> get props => [
        planningMeetings,
        parentMeetings,
        youthCouncilAttendance,
        churchBoardAttendance,
        soulTarget,
        unbaptizedMembers,
        bibleStudiesReceiving,
        hasWeeklyBibleInstruction,
        bibleStudiesGiven,
        literatureDistributed,
        baptizedThisMonth,
        totalBaptized,
        clubParticipationDescription,
        communityServiceDescription,
        certificatesDelivered,
        membersHaveBooklet,
        bookletRequirementsSigned,
      ];
}

/// Entidad de informe mensual
class MonthlyReport extends Equatable {
  final String id;
  final String enrollmentId;
  final int month;
  final int year;
  final String status;

  // Datos automáticos (calculados por el sistema)
  final int? totalActivities;
  final int? totalAttendance;
  final int? totalMembers;
  final double? attendanceRate;

  // Datos manuales legacy
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
    this.clubName,
    this.clubType,
    this.snapshot,
    this.manualData,
    this.generatedAt,
    this.submittedAt,
    this.createdAt,
  });

  MonthlyReportStatus get reportStatus {
    switch (status) {
      case 'submitted':
        return MonthlyReportStatus.submitted;
      case 'generated':
        return MonthlyReportStatus.generated;
      case 'approved':
        return MonthlyReportStatus.approved;
      case 'rejected':
        return MonthlyReportStatus.rejected;
      default:
        return MonthlyReportStatus.draft;
    }
  }

  bool get canEditManualData => reportStatus == MonthlyReportStatus.draft;
  bool get canGenerate => false;
  bool get canDownloadPdf =>
      reportStatus == MonthlyReportStatus.generated ||
      reportStatus == MonthlyReportStatus.submitted ||
      reportStatus == MonthlyReportStatus.approved;

  String get monthName {
    const keys = [
      '',
      'january',
      'february',
      'march',
      'april',
      'may',
      'june',
      'july',
      'august',
      'september',
      'october',
      'november',
      'december',
    ];
    if (month >= 1 && month <= 12) return tr('common.months.${keys[month]}');
    return tr('common.months.unknown', namedArgs: {'month': '$month'});
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

/// Preview de un informe mensual (datos calculados antes de guardar)
class MonthlyReportPreview extends Equatable {
  final String enrollmentId;
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

/// Item liviano del listado jerárquico de reportes visibles para el actor.
class VisibleMonthlyReport extends Equatable {
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

  const VisibleMonthlyReport({
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

  MonthlyReportStatus get reportStatus {
    switch (status) {
      case 'generated':
        return MonthlyReportStatus.generated;
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
    const keys = [
      '',
      'january',
      'february',
      'march',
      'april',
      'may',
      'june',
      'july',
      'august',
      'september',
      'october',
      'november',
      'december',
    ];
    if (month >= 1 && month <= 12) return tr('common.months.${keys[month]}');
    return tr('common.months.unknown', namedArgs: {'month': '$month'});
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

class VisibleMonthlyReportsPage extends Equatable {
  final int total;
  final int page;
  final int limit;
  final List<VisibleMonthlyReport> items;

  const VisibleMonthlyReportsPage({
    required this.total,
    required this.page,
    required this.limit,
    required this.items,
  });

  @override
  List<Object?> get props => [total, page, limit, items];
}
