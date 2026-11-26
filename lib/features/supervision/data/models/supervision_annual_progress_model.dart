import '../../domain/entities/supervision_annual_progress.dart';

Map<String, dynamic>? _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : null;

String? _str(Object? v) {
  if (v == null || v is Map || v is List) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

String _text(Object? v) => _str(v) ?? '';

int? _int(Object? v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.toInt();
  return null;
}

double? _double(Object? v) {
  final d = v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
  return d == null || d.isNaN || d.isInfinite ? null : d;
}

double _percent(Object? v) => (_double(v) ?? 0).clamp(0, 100).toDouble();

List<Map<String, dynamic>> _maps(Object? v) => v is List
    ? v.map(_map).whereType<Map<String, dynamic>>().toList()
    : const [];

class SupervisionAnnualProgressModel {
  const SupervisionAnnualProgressModel._();

  /// `{union_id|local_field_id, name}`; rows without the id are dropped.
  /// [parentKey] (`division_id` / `union_id`), when present on a row, must
  /// equal [parentId]: rows of other parents are discarded.
  static List<SupervisionTerritoryOption> parseOptions(
    Object? raw, {
    required String idKey,
    required String parentKey,
    required int parentId,
  }) {
    final options = <SupervisionTerritoryOption>[];
    for (final json in _maps(raw)) {
      final id = _int(json[idKey]);
      if (id == null) continue;
      final parent = _int(json[parentKey]);
      if (parent != null && parent != parentId) continue;
      options
          .add(SupervisionTerritoryOption(id: id, name: _text(json['name'])));
    }
    return options;
  }

  /// `GET /annual-rankings/territory-summary`: `{id, name, clubs_count,
  /// configured, gold_or_better_count}` per territory; rows without an id are
  /// dropped. A field the server leaves out or sends malformed stays null
  /// (unknown), never 0/true. `gold_or_better_count` is null on purpose while
  /// the nightly job has not computed the year yet.
  static List<SupervisionTerritoryOption> parseTerritorySummary(Object? raw) {
    final options = <SupervisionTerritoryOption>[];
    for (final json in _maps(raw)) {
      final id = _int(json['id']);
      if (id == null) continue;
      final configured = json['configured'];
      final gold = _int(json['gold_or_better_count']);
      options.add(
        SupervisionTerritoryOption(
          id: id,
          name: _text(json['name']),
          clubsCount: _int(json['clubs_count']),
          configured: configured is bool ? configured : null,
          goldOrBetterCount: gold == null || gold < 0 ? null : gold,
        ),
      );
    }
    return options;
  }

  static SupervisionProgressTier? tryParseTier(Object? raw) {
    final json = _map(raw);
    if (json == null) return null;
    return SupervisionProgressTier(
      name: _text(json['name']),
      slug: _text(json['slug']),
      fromPoints: _double(json['from_points']) ?? 0,
      toPoints: _double(json['to_points']) ?? 0,
      pointsToReach: _double(json['points_to_reach']),
    );
  }

  static SupervisionProgressComponent? tryParseComponent(Object? raw) {
    final json = _map(raw);
    if (json == null) return null;
    final key = _str(json['key']);
    if (key == null) return null;
    return SupervisionProgressComponent(
      key: key,
      label: _text(json['label']),
      earnedPoints: _double(json['earned_points']) ?? 0,
      maxPoints: _double(json['max_points']) ?? 0,
      progressPercentage: _percent(json['progress_percentage']),
    );
  }

  static SupervisionProgressAxis? tryParseAxis(Object? raw) {
    final json = _map(raw);
    if (json == null) return null;
    final key = _str(json['key']);
    if (key == null) return null;
    return SupervisionProgressAxis(
      key: key,
      label: _text(json['label']),
      earnedPoints: _double(json['earned_points']) ?? 0,
      maxPoints: _double(json['max_points']) ?? 0,
      progressPercentage: _percent(json['progress_percentage']),
      components: _maps(json['components'])
          .map(tryParseComponent)
          .whereType<SupervisionProgressComponent>()
          .toList(),
    );
  }

  /// Null when the row has no club id or club section id.
  /// `rank_position` is deliberately ignored.
  static SupervisionClubProgress? tryParseClub(Object? raw) {
    final json = _map(raw);
    if (json == null) return null;
    final clubId = _int(json['club_id']);
    final sectionId = _int(json['club_section_id']);
    if (clubId == null || sectionId == null) return null;
    return SupervisionClubProgress(
      clubId: clubId,
      clubSectionId: sectionId,
      clubName: _text(json['club_name']),
      currentPoints: _double(json['current_points']) ?? 0,
      maxPoints: _double(json['max_points']) ?? 0,
      progressPercentage: _percent(json['progress_percentage']),
      currentTier: tryParseTier(json['current_tier']),
      nextTier: tryParseTier(json['next_tier']),
      axes: _maps(json['axes'])
          .map(tryParseAxis)
          .whereType<SupervisionProgressAxis>()
          .toList(),
      components: _maps(json['components'])
          .map(tryParseComponent)
          .whereType<SupervisionProgressComponent>()
          .toList(),
    );
  }

  /// Rows sorted by progress desc, then points desc, then club name.
  static SupervisionAnnualProgress parse(Object? raw) {
    final clubs = _maps(raw)
        .map(tryParseClub)
        .whereType<SupervisionClubProgress>()
        .toList()
      ..sort((a, b) {
        final byProgress = b.progressPercentage.compareTo(a.progressPercentage);
        if (byProgress != 0) return byProgress;
        final byPoints = b.currentPoints.compareTo(a.currentPoints);
        if (byPoints != 0) return byPoints;
        return a.clubName.toLowerCase().compareTo(b.clubName.toLowerCase());
      });
    return SupervisionAnnualProgress(configured: true, clubs: clubs);
  }
}
