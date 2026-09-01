import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_event.dart';
import 'package:sacdia_app/features/camporees/domain/utils/camporee_event_agenda.dart';

void main() {
  group('CamporeeEvent.isScored', () {
    test('should treat scoring_enabled as official scored events', () {
      expect(
        _event(scoringEnabled: true, eventTypeCode: 'spiritual').isScored,
        isTrue,
      );
    });

    test('should treat type scoring as scored when the preview omits the flag',
        () {
      expect(_event(eventTypeCode: 'scoring').isScored, isTrue);
    });

    test('should leave spiritual and recreational events off the scored list',
        () {
      expect(_event(eventTypeCode: 'spiritual').isScored, isFalse);
      expect(_event(eventTypeCode: 'recreational').isScored, isFalse);
    });
  });

  group('buildCamporeeAgendaEntries', () {
    test('should expand schedule blocks into one row each', () {
      final event = _event(
        id: 7,
        title: 'Orden cerrado',
        dayNumber: 1,
        startsAt: '09:00',
        scheduleBlocks: const [
          CamporeeEventScheduleBlock(
            title: 'Grupo A',
            dayNumber: 1,
            startsAt: '09:00',
            venueName: 'Cancha 1',
          ),
          CamporeeEventScheduleBlock(
            title: 'Grupo B',
            dayNumber: 2,
            startsAt: '08:30',
            venueName: 'Cancha 2',
          ),
        ],
      );

      final entries = buildCamporeeAgendaEntries([event]);

      expect(entries, hasLength(2));
      expect(entries.first.headline, 'Orden cerrado · Grupo A');
      expect(entries.first.dayNumber, 1);
      expect(entries.first.startsAt, '09:00');
      expect(entries.last.headline, 'Orden cerrado · Grupo B');
      expect(entries.last.dayNumber, 2);
    });

    test('should fall back to the event clock when there are no blocks', () {
      final entries = buildCamporeeAgendaEntries([
        _event(id: 1, title: 'Culto', dayNumber: 1, startsAt: '07:00'),
      ]);

      expect(entries, hasLength(1));
      expect(entries.single.headline, 'Culto');
      expect(entries.single.startsAt, '07:00');
      expect(entries.single.dayNumber, 1);
    });

    test('should sort by day then clock then title', () {
      final entries = buildCamporeeAgendaEntries([
        _event(id: 2, title: 'Nudos', dayNumber: 2, startsAt: '08:00'),
        _event(id: 3, title: 'Fútbol', dayNumber: 2, startsAt: '16:00'),
        _event(id: 1, title: 'Culto', dayNumber: 1, startsAt: '07:00'),
        _event(id: 4, title: 'Sin hora', dayNumber: 1),
      ]);

      expect(
        entries.map((entry) => entry.headline).toList(),
        ['Culto', 'Sin hora', 'Nudos', 'Fútbol'],
      );
    });
  });

  group('groupCamporeeAgendaByDay', () {
    test('should keep chronological day buckets', () {
      final grouped = groupCamporeeAgendaByDay(
        buildCamporeeAgendaEntries([
          _event(id: 2, title: 'Nudos', dayNumber: 2, startsAt: '08:00'),
          _event(id: 1, title: 'Culto', dayNumber: 1, startsAt: '07:00'),
        ]),
      );

      expect(grouped.map((group) => group.$1).toList(), [1, 2]);
      expect(grouped.first.$2.single.headline, 'Culto');
      expect(grouped.last.$2.single.headline, 'Nudos');
    });
  });

  group('formatCamporeeClock', () {
    test('should normalize hour strings with seconds', () {
      expect(formatCamporeeClock('9:00:00'), '09:00');
      expect(formatCamporeeClock('16:30'), '16:30');
      expect(formatCamporeeClock(null), isNull);
    });
  });

  group('camporeeAgendaDayDate', () {
    test('should add calendar days without shifting the start date', () {
      final start = DateTime(2026, 8, 15);
      expect(camporeeAgendaDayDate(start, 1), DateTime(2026, 8, 15));
      expect(camporeeAgendaDayDate(start, 3), DateTime(2026, 8, 17));
    });
  });
}

CamporeeEvent _event({
  int id = 1,
  String title = 'Evento',
  int dayNumber = 1,
  String? startsAt,
  bool scoringEnabled = false,
  String? eventTypeCode,
  List<CamporeeEventScheduleBlock> scheduleBlocks = const [],
}) {
  return CamporeeEvent(
    camporeeEventId: id,
    title: title,
    maxPoints: 0,
    minPoints: 0,
    dayNumber: dayNumber,
    startsAt: startsAt,
    displayCategory: 'logistico',
    status: 'programado',
    participantsMode: 'count',
    scoringEnabled: scoringEnabled,
    eventTypeCode: eventTypeCode,
    scheduleBlocks: scheduleBlocks,
  );
}
