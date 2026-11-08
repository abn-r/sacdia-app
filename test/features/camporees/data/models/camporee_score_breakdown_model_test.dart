import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/camporees/data/models/camporee_score_breakdown_model.dart';

Map<String, dynamic> _result({
  int eventId = 27,
  String status = 'scored',
  bool noShow = false,
  Object awarded = 430,
  Object max = 500,
}) =>
    {
      'camporee_event_id': eventId,
      'camporee_event_section_result_id': 'r-$eventId',
      'score_status': status,
      'is_no_show': noShow,
      'total_awarded_points': awarded,
      'total_max_points': max,
      'raw_awarded_points': awarded,
      'minimum_adjustment_points': 0,
      'notes': 'Buena formación',
      'submitted_at': '2026-11-01T10:00:00.000Z',
      'evaluator_name': 'Ana Ruiz',
      'items': [
        {
          'camporee_event_rubric_id': 1,
          'title': 'Uniforme',
          'awarded_points': '250.00',
          'max_points': 300,
          'notes': 'Falta pañoleta',
        },
        {
          'camporee_event_rubric_id': 2,
          'title': 'Cadencia',
          'awarded_points': 180,
          'max_points': 200,
          'notes': null,
        },
      ],
    };

Map<String, dynamic> _section(int id, String club, List<dynamic> results,
        {int? rank}) =>
    {
      'rank': rank,
      'camporee_club_id': 6,
      'club_section_id': id,
      'club_name': club,
      'section_name': 'Conquistadores',
      'total_awarded_points': '1035',
      'total_max_points': 1200,
      'scored_events_count': 6,
      'percentage': 86.25,
      'results': results,
    };

void main() {
  group('CamporeeScoreBreakdownModel', () {
    test('parses the own view with item notes and string numbers', () {
      final entity = CamporeeScoreBreakdownModel.fromJson({
        'scope': {'type': 'local', 'camporeeId': 74},
        'visibility': 'own',
        'events': [],
        'sections': [
          _section(12, 'ACV', [_result()]),
        ],
      }).toEntity();

      expect(entity.isOwn, isTrue);
      expect(entity.camporeeId, 74);
      final section = entity.sections.single;
      expect(section.rank, isNull);
      expect(section.totalAwardedPoints, 1035);
      final score = section.results.single.score;
      expect(section.results.single.camporeeEventId, 27);
      expect(score.totalAwarded, 430);
      expect(score.notes, 'Buena formación');
      expect(score.evaluatorName, 'Ana Ruiz');
      expect(score.submittedAt, isNotNull);
      expect(score.items.first.awardedPoints, 250);
      expect(score.items.first.notes, 'Falta pañoleta');
      expect(score.items.last.notes, isNull);
    });

    test('parses the full view and orders an event by points desc', () {
      final entity = CamporeeScoreBreakdownModel.fromJson({
        'scope': {'type': 'local', 'camporeeId': 74},
        'visibility': 'full',
        'sections': [
          _section(12, 'ACV', [_result(awarded: 300)], rank: 2),
          _section(13, 'Orión', [_result(awarded: 450)], rank: 1),
          _section(14, 'Sin puntaje', [_result(eventId: 99)], rank: 3),
        ],
      }).toEntity();

      expect(entity.isOwn, isFalse);
      expect(entity.sections.first.rank, 2);
      final entries = entity.entriesForEvent(27);
      expect(entries.map((e) => e.section.clubName), ['Orión', 'ACV']);
    });

    test('keeps no_show results', () {
      final entity = CamporeeScoreBreakdownModel.fromJson({
        'visibility': 'own',
        'sections': [
          _section(12, 'ACV', [
            _result(status: 'no_show', noShow: true, awarded: 0),
          ]),
        ],
      }).toEntity();

      final score = entity.sections.single.results.single.score;
      expect(score.isNoShow, isTrue);
      expect(score.scoreStatus, 'no_show');
      expect(score.totalAwarded, 0);
    });

    test('tolerates a payload without sections', () {
      final entity = CamporeeScoreBreakdownModel.fromJson({}).toEntity();
      expect(entity.sections, isEmpty);
      expect(entity.visibility, 'full');
    });
  });
}
