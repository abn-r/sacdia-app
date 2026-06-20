import 'package:equatable/equatable.dart';

class ProgressScopeClass extends Equatable {
  final int classId;
  final String name;
  final int clubTypeId;
  final String accessLevel;

  const ProgressScopeClass({
    required this.classId,
    required this.name,
    required this.clubTypeId,
    required this.accessLevel,
  });

  @override
  List<Object?> get props => [classId, name, clubTypeId, accessLevel];
}

class ProgressScopeResult extends Equatable {
  final int clubSectionId;
  final int clubTypeId;
  final int ecclesiasticalYearId;
  final String accessLevel;
  final List<ProgressScopeClass> classes;

  const ProgressScopeResult({
    required this.clubSectionId,
    required this.clubTypeId,
    required this.ecclesiasticalYearId,
    required this.accessLevel,
    required this.classes,
  });

  bool get hasSectionWideAccess => accessLevel == 'section';

  @override
  List<Object?> get props => [
        clubSectionId,
        clubTypeId,
        ecclesiasticalYearId,
        accessLevel,
        classes,
      ];
}
