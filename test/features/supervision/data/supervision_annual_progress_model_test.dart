import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/supervision/data/models/supervision_annual_progress_model.dart';

Map<String, dynamic> _row(
  int id,
  String name, {
  Object? progress = 50,
  Object? points = 10,
  Map<String, dynamic>? extra,
}) =>
    {
      'rank_position': 9,
      'club_enrollment_id': 'e$id',
      'club_section_id': id * 10,
      'club_id': id,
      'club_name': name,
      'club_type_id': 1,
      'current_points': points,
      'max_points': 100,
      'progress_percentage': progress,
      ...?extra,
    };

void main() {
  test('parses a row with tiers, axes and nested components', () {
    final result = SupervisionAnnualProgressModel.parse([
      _row(1, 'Orion', extra: {
        'current_points': '42.5',
        'current_tier': {
          'name': 'Oro',
          'slug': 'gold',
          'from_points': 40,
          'to_points': 60,
        },
        'next_tier': {
          'name': 'Platino',
          'slug': 'platinum',
          'from_points': 60,
          'to_points': 80,
          'points_to_reach': 17.5,
        },
        'axes': [
          {
            'key': 'a1',
            'label': 'Eje',
            'earned_points': 5,
            'max_points': 10,
            'progress_percentage': 50,
            'components': [
              {
                'key': 'c1',
                'label': 'Comp',
                'earned_points': 2,
                'max_points': 4,
                'progress_percentage': 50,
              },
              {'label': 'sin key'},
            ],
          },
        ],
        'components': [
          {'key': 'c2', 'label': 'Suelto', 'earned_points': 1, 'max_points': 2},
        ],
      }),
    ]);
    expect(result.configured, isTrue);
    final c = result.clubs.single;
    expect(c.clubId, 1);
    expect(c.clubSectionId, 10);
    expect(c.currentPoints, 42.5);
    expect(c.currentTier!.slug, 'gold');
    expect(c.currentTier!.pointsToReach, isNull);
    expect(c.nextTier!.pointsToReach, 17.5);
    expect(c.axes.single.components.single.key, 'c1');
    expect(c.axes.single.progressPercentage, 50);
    expect(c.components.single.label, 'Suelto');
  });

  test('clamps progress to 0..100', () {
    final r = SupervisionAnnualProgressModel.parse([
      _row(1, 'A', progress: 140),
      _row(2, 'B', progress: -5),
      _row(3, 'C', progress: 'x'),
    ]);
    expect(r.clubs.map((c) => c.progressPercentage), [100, 0, 0]);
  });

  test('sorts by progress, then points, then name (case-insensitive)', () {
    final r = SupervisionAnnualProgressModel.parse([
      _row(1, 'beta', progress: 50, points: 5),
      _row(2, 'Alfa', progress: 50, points: 5),
      _row(3, 'Zeta', progress: 50, points: 9),
      _row(4, 'Low', progress: 10, points: 99),
      _row(5, 'Top', progress: 90, points: 1),
    ]);
    expect(
        r.clubs.map((c) => c.clubName), ['Top', 'Zeta', 'Alfa', 'beta', 'Low']);
  });

  test('drops rows without ids and tolerates wrong types', () {
    final r = SupervisionAnnualProgressModel.parse([
      {'club_name': 'x'},
      'junk',
      null,
      _row(1, 'Ok', extra: {'axes': 'x', 'current_tier': 3, 'components': {}}),
    ]);
    expect(r.clubs.single.clubName, 'Ok');
    expect(r.clubs.single.axes, isEmpty);
    expect(r.clubs.single.currentTier, isNull);
    expect(SupervisionAnnualProgressModel.parse(null).clubs, isEmpty);
    expect(SupervisionAnnualProgressModel.parse(null).configured, isTrue);
  });

  test('options keep rows without parent id and drop other parents', () {
    final o = SupervisionAnnualProgressModel.parseOptions(
      [
        {'union_id': 1, 'name': 'A', 'division_id': 5},
        {'union_id': 2, 'name': 'B', 'division_id': 6},
        {'union_id': 3, 'name': 'C'},
        {'name': 'sin id'},
      ],
      idKey: 'union_id',
      parentKey: 'division_id',
      parentId: 5,
    );
    expect(o.map((e) => e.id), [1, 3]);
  });
}
