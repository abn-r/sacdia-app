import 'package:equatable/equatable.dart';

class CoordinatorScope extends Equatable {
  final bool isCoordinator;
  final List<int> clubSectionIds;
  final List<CoordinatorSectionScope> sections;

  const CoordinatorScope({
    required this.isCoordinator,
    this.clubSectionIds = const [],
    this.sections = const [],
  });

  bool get hasAssignedSections => clubSectionIds.isNotEmpty;

  @override
  List<Object?> get props => [isCoordinator, clubSectionIds, sections];
}

class CoordinatorSectionScope extends Equatable {
  final int clubSectionId;
  final String? name;
  final int clubTypeId;
  final String? clubTypeName;
  final int? clubId;
  final String? clubName;
  final int? districtId;
  final String? districtName;
  final int? localFieldId;
  final String? localFieldName;

  const CoordinatorSectionScope({
    required this.clubSectionId,
    this.name,
    required this.clubTypeId,
    this.clubTypeName,
    this.clubId,
    this.clubName,
    this.districtId,
    this.districtName,
    this.localFieldId,
    this.localFieldName,
  });

  String get displayName {
    final type = clubTypeName?.trim();
    if (type != null && type.isNotEmpty) return type;

    final sectionName = name?.trim();
    if (sectionName != null && sectionName.isNotEmpty) return sectionName;

    return 'Sección #$clubSectionId';
  }

  @override
  List<Object?> get props => [
        clubSectionId,
        name,
        clubTypeId,
        clubTypeName,
        clubId,
        clubName,
        districtId,
        districtName,
        localFieldId,
        localFieldName,
      ];
}
