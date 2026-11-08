import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_event.dart';
import 'package:sacdia_app/features/camporees/domain/utils/camporee_event_agenda.dart';

CamporeeEvent _event(
  int id,
  String title, {
  int day = 1,
  String? startsAt,
  String? endsAt,
  int? durationSeconds,
  String status = 'publicado',
  bool agendaVisible = true,
  List<CamporeeEventScheduleBlock> blocks = const [],
}) =>
    CamporeeEvent(
      camporeeEventId: id,
      title: title,
      maxPoints: 0,
      minPoints: 0,
      dayNumber: day,
      startsAt: startsAt,
      endsAt: endsAt,
      durationSeconds: durationSeconds,
      displayCategory: 'logistico',
      status: status,
      participantsMode: 'all',
      agendaVisible: agendaVisible,
      scheduleBlocks: blocks,
    );

// Day 1 = Monday 10 Feb 2027.
final _start = DateTime(2027, 2, 10);

CamporeeAgendaNow _resolve(List<CamporeeEvent> events, DateTime now) =>
    resolveCamporeeAgendaNow(
      buildCamporeeAgendaEntries(events),
      startDate: _start,
      now: now,
    );

List<String> _titles(List<CamporeeAgendaSlot> slots) =>
    [for (final slot in slots) slot.entry.headline];

void main() {
  final program = [
    _event(1, 'Desayuno', startsAt: '07:30', endsAt: '08:30'),
    _event(2, 'Limpieza', startsAt: '09:00', endsAt: '10:00'),
    _event(3, 'Nudos', startsAt: '10:30', endsAt: '12:00'),
    _event(4, 'Primeros auxilios', startsAt: '10:30', endsAt: '11:30'),
    _event(5, 'Fogata', day: 2, startsAt: '20:00', endsAt: '21:30'),
  ];

  test('between activities: nothing in progress, the next one is shown', () {
    final now = _resolve(program, DateTime(2027, 2, 10, 8, 45));
    expect(now.current, isEmpty);
    expect(_titles(now.next), ['Limpieza']);
  });

  test(
      'during an activity: it is in progress and the parallel next ones follow',
      () {
    final now = _resolve(program, DateTime(2027, 2, 10, 9, 15));
    expect(_titles(now.current), ['Limpieza']);
    expect(_titles(now.next), ['Nudos', 'Primeros auxilios']);
  });

  test('parallel activities are all in progress', () {
    final now = _resolve(program, DateTime(2027, 2, 10, 11));
    expect(_titles(now.current), ['Nudos', 'Primeros auxilios']);
    expect(_titles(now.next), ['Fogata']);
    expect(now.next.single.start, DateTime(2027, 2, 11, 20));
  });

  test('before the camporee the first activity is next', () {
    final now = _resolve(program, DateTime(2027, 2, 1, 12));
    expect(now.current, isEmpty);
    expect(_titles(now.next), ['Desayuno']);
  });

  test('after the program there is nothing to show', () {
    expect(_resolve(program, DateTime(2027, 2, 11, 22)).isEmpty, isTrue);
  });

  test('skips cancelled, hidden and unscheduled activities', () {
    final now = _resolve([
      _event(1, 'Cancelada', startsAt: '09:00', status: 'cancelado'),
      _event(2, 'Oculta', startsAt: '09:00', agendaVisible: false),
      _event(3, 'Sin hora'),
      _event(4, 'Inspección', startsAt: '10:00'),
    ], DateTime(2027, 2, 10, 8));
    expect(_titles(now.next), ['Inspección']);
  });

  test('without end time it lasts its duration, or one hour', () {
    final events = [
      _event(1, 'Con duración', startsAt: '09:00', durationSeconds: 1800),
      _event(2, 'Sin duración', startsAt: '09:00'),
    ];
    final at = _resolve(events, DateTime(2027, 2, 10, 9, 45));
    expect(_titles(at.current), ['Sin duración']);
  });

  test(
      'status en_curso keeps an activity in progress that day; realizado ends it',
      () {
    final events = [
      _event(1, 'Marcha',
          startsAt: '08:00', endsAt: '09:00', status: 'en_curso'),
      _event(2, 'Bíblico',
          startsAt: '09:00', endsAt: '10:00', status: 'realizado'),
    ];
    final now = _resolve(events, DateTime(2027, 2, 10, 9, 30));
    expect(_titles(now.current), ['Marcha']);
  });

  test('uses schedule blocks when the event has them', () {
    final events = [
      _event(1, 'Taller', blocks: const [
        CamporeeEventScheduleBlock(
          title: 'Turno A',
          dayNumber: 1,
          startsAt: '09:00',
          endsAt: '10:00',
        ),
        CamporeeEventScheduleBlock(
          title: 'Turno B',
          dayNumber: 1,
          startsAt: '10:00',
          endsAt: '11:00',
        ),
      ]),
    ];
    final now = _resolve(events, DateTime(2027, 2, 10, 9, 30));
    expect(_titles(now.current), ['Taller · Turno A']);
    expect(_titles(now.next), ['Taller · Turno B']);
  });
}
