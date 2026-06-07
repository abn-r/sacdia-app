import 'package:equatable/equatable.dart';

/// Lightweight domain entity for a club section used by joint activity flows.
class ActivityClubSection extends Equatable {
  final int clubSectionId;
  final int clubTypeId;
  final String? clubTypeName;
  final bool active;

  const ActivityClubSection({
    required this.clubSectionId,
    required this.clubTypeId,
    this.clubTypeName,
    required this.active,
  });

  @override
  List<Object?> get props => [clubSectionId, clubTypeId, clubTypeName, active];
}
