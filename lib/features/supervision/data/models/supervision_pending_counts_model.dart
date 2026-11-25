import '../../domain/entities/supervision_pending_counts.dart';

class SupervisionPendingCountsModel extends SupervisionPendingCounts {
  const SupervisionPendingCountsModel({
    required super.territoryLevel,
    super.clubEnrollments,
    super.annualFolders,
    super.unionCamporeeRegistrations,
    super.transfers,
    super.roleAssignments,
  });

  /// Tolerant parser: missing keys, wrong types or a missing `counts` object
  /// yield null counts, never an exception.
  factory SupervisionPendingCountsModel.fromJson(Map<String, dynamic> json) {
    final rawCounts = json['counts'];
    final counts = rawCounts is Map ? rawCounts : const <Object?, Object?>{};
    final level = json['territory_level'];

    return SupervisionPendingCountsModel(
      territoryLevel: level is String ? level : 'unconfigured',
      clubEnrollments: _count(counts['club_enrollments']),
      annualFolders: _count(counts['annual_folders']),
      unionCamporeeRegistrations:
          _count(counts['union_camporee_registrations']),
      transfers: _count(counts['transfers']),
      roleAssignments: _count(counts['role_assignments']),
    );
  }

  static int? _count(Object? value) => value is int ? value : null;
}
