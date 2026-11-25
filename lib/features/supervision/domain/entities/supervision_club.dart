import 'package:equatable/equatable.dart';

enum SupervisionClubActiveFilter { all, active, inactive }

class SupervisionClubSection extends Equatable {
  const SupervisionClubSection({
    required this.id,
    required this.clubTypeId,
    required this.typeName,
    required this.active,
    this.soulsTarget,
    this.phone,
    this.email,
  });

  final int id;
  final int clubTypeId;
  final String typeName;
  final bool active;
  final int? soulsTarget;
  final String? phone;
  final String? email;

  @override
  List<Object?> get props =>
      [id, clubTypeId, typeName, active, soulsTarget, phone, email];
}

/// Type names of the active sections, in server order, no blanks, no
/// duplicates.
List<String> _activeSectionNames(List<SupervisionClubSection> sections) {
  final seen = <String>{};
  return [
    for (final s in sections)
      if (s.active && s.typeName.isNotEmpty && seen.add(s.typeName)) s.typeName,
  ];
}

class SupervisionClubListItem extends Equatable {
  const SupervisionClubListItem({
    required this.id,
    required this.name,
    required this.active,
    required this.churchName,
    required this.districtName,
    required this.localFieldName,
    required this.sections,
  });

  final int id;
  final String name;
  final bool active;
  final String churchName;
  final String districtName;
  final String localFieldName;
  final List<SupervisionClubSection> sections;

  List<String> get activeSectionNames => _activeSectionNames(sections);

  @override
  List<Object?> get props =>
      [id, name, active, churchName, districtName, localFieldName, sections];
}

class SupervisionClubPage extends Equatable {
  const SupervisionClubPage({
    required this.items,
    required this.page,
    required this.total,
    required this.hasMore,
  });

  final List<SupervisionClubListItem> items;
  final int page;
  final int total;
  final bool hasMore;

  @override
  List<Object?> get props => [items, page, total, hasMore];
}

class SupervisionClubProfile extends Equatable {
  const SupervisionClubProfile({
    required this.id,
    required this.name,
    required this.active,
    required this.description,
    required this.address,
    required this.churchName,
    required this.districtName,
    required this.localFieldName,
    required this.sections,
  });

  final int id;
  final String name;
  final bool active;
  final String? description;
  final String? address;
  final String churchName;
  final String districtName;
  final String localFieldName;
  final List<SupervisionClubSection> sections;

  List<String> get activeSectionNames => _activeSectionNames(sections);

  @override
  List<Object?> get props => [
        id,
        name,
        active,
        description,
        address,
        churchName,
        districtName,
        localFieldName,
        sections,
      ];
}

class SupervisionClubEvent extends Equatable {
  const SupervisionClubEvent({
    required this.id,
    required this.name,
    required this.date,
    required this.sectionName,
  });

  final int id;
  final String name;
  final DateTime? date;
  final String? sectionName;

  @override
  List<Object?> get props => [id, name, date, sectionName];
}

class SupervisionClubOverview extends Equatable {
  const SupervisionClubOverview({
    required this.attendanceAverage,
    required this.activeMembers,
    required this.investedThisYear,
    required this.pendingRequests,
    required this.upcomingEvents,
  });

  /// 0-100, null when there is no attendance data.
  final double? attendanceAverage;
  final int activeMembers;
  final int investedThisYear;
  final int pendingRequests;
  final List<SupervisionClubEvent> upcomingEvents;

  @override
  List<Object?> get props => [
        attendanceAverage,
        activeMembers,
        investedThisYear,
        pendingRequests,
        upcomingEvents,
      ];
}

class SupervisionClubLeader extends Equatable {
  const SupervisionClubLeader({
    required this.userId,
    required this.fullName,
    required this.roleName,
    required this.sectionName,
  });

  final String userId;
  final String fullName;
  final String roleName;
  final String? sectionName;

  @override
  List<Object?> get props => [userId, fullName, roleName, sectionName];
}

class SupervisionClubLeadership extends Equatable {
  const SupervisionClubLeadership({
    required this.director,
    required this.deputies,
    required this.secretaries,
  });

  final SupervisionClubLeader? director;
  final List<SupervisionClubLeader> deputies;
  final List<SupervisionClubLeader> secretaries;

  bool get isEmpty =>
      director == null && deputies.isEmpty && secretaries.isEmpty;

  @override
  List<Object?> get props => [director, deputies, secretaries];
}

/// Everything the club summary screen shows. Overview and leadership are
/// secondary: null when their request failed.
class SupervisionClubSummary extends Equatable {
  const SupervisionClubSummary({
    required this.profile,
    required this.overview,
    required this.leadership,
  });

  final SupervisionClubProfile profile;
  final SupervisionClubOverview? overview;
  final SupervisionClubLeadership? leadership;

  @override
  List<Object?> get props => [profile, overview, leadership];
}
