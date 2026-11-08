import 'package:equatable/equatable.dart';

import '../entities/camporee_event.dart';

/// Fila de agenda: el evento o uno de sus bloques horarios.
class CamporeeAgendaEntry extends Equatable {
  final CamporeeEvent event;
  final int dayNumber;
  final String? startsAt;
  final String? endsAt;
  final String? venueName;
  final String? blockTitle;

  const CamporeeAgendaEntry({
    required this.event,
    required this.dayNumber,
    this.startsAt,
    this.endsAt,
    this.venueName,
    this.blockTitle,
  });

  String get headline {
    final block = blockTitle?.trim();
    if (block == null || block.isEmpty || block == event.title) {
      return event.title;
    }
    return '${event.title} · $block';
  }

  @override
  List<Object?> get props => [
        event.camporeeEventId,
        dayNumber,
        startsAt,
        endsAt,
        venueName,
        blockTitle,
      ];
}

/// Expande eventos y bloques, orden día → hora → título.
List<CamporeeAgendaEntry> buildCamporeeAgendaEntries(
  List<CamporeeEvent> events,
) {
  final entries = <CamporeeAgendaEntry>[];

  for (final event in events) {
    if (event.scheduleBlocks.isNotEmpty) {
      for (final block in event.scheduleBlocks) {
        entries.add(
          CamporeeAgendaEntry(
            event: event,
            dayNumber: block.dayNumber,
            startsAt: block.startsAt,
            endsAt: block.endsAt,
            venueName: block.venueName ?? event.venueName,
            blockTitle: block.title,
          ),
        );
      }
      continue;
    }

    entries.add(
      CamporeeAgendaEntry(
        event: event,
        dayNumber: event.dayNumber,
        startsAt: event.startsAt,
        endsAt: event.endsAt,
        venueName: event.venueName,
      ),
    );
  }

  entries.sort(compareCamporeeAgendaEntries);
  return entries;
}

int compareCamporeeAgendaEntries(
  CamporeeAgendaEntry a,
  CamporeeAgendaEntry b,
) {
  final day = a.dayNumber.compareTo(b.dayNumber);
  if (day != 0) return day;
  final time = camporeeClockMinutes(a.startsAt)
      .compareTo(camporeeClockMinutes(b.startsAt));
  if (time != 0) return time;
  return a.headline.compareTo(b.headline);
}

List<(int day, List<CamporeeAgendaEntry> items)> groupCamporeeAgendaByDay(
  List<CamporeeAgendaEntry> entries,
) {
  final grouped = <int, List<CamporeeAgendaEntry>>{};
  for (final entry in entries) {
    grouped.putIfAbsent(entry.dayNumber, () => []).add(entry);
  }
  final days = grouped.keys.toList()..sort();
  return [for (final day in days) (day, grouped[day]!)];
}

/// Minutos desde 00:00. Sin hora → al final del día.
int camporeeClockMinutes(String? raw) {
  final formatted = formatCamporeeClock(raw);
  if (formatted == null) return (24 * 60) + 1;
  final parts = formatted.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

String? formatCamporeeClock(String? raw) {
  if (raw == null) return null;
  final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw.trim());
  if (match == null) return null;
  return '${match.group(1)!.padLeft(2, '0')}:${match.group(2)}';
}

DateTime camporeeAgendaDayDate(DateTime startDate, int dayNumber) {
  final dayOffset = dayNumber < 1 ? 0 : dayNumber - 1;
  return DateTime(startDate.year, startDate.month, startDate.day + dayOffset);
}

/// A program slot placed on the calendar.
class CamporeeAgendaSlot extends Equatable {
  final CamporeeAgendaEntry entry;
  final DateTime start;
  final DateTime end;

  const CamporeeAgendaSlot({
    required this.entry,
    required this.start,
    required this.end,
  });

  @override
  List<Object?> get props => [entry, start, end];
}

/// What is happening now and what comes next in the program.
class CamporeeAgendaNow extends Equatable {
  /// Activities running at [now] (several when they run in parallel).
  final List<CamporeeAgendaSlot> current;

  /// The activities that start next, all at the same time.
  final List<CamporeeAgendaSlot> next;

  const CamporeeAgendaNow({this.current = const [], this.next = const []});

  bool get isEmpty => current.isEmpty && next.isEmpty;

  @override
  List<Object?> get props => [current, next];
}

/// Default length of an activity without an end time or a duration.
const Duration kCamporeeDefaultActivityLength = Duration(hours: 1);

/// Places each visible, scheduled and not cancelled entry on the calendar
/// (day 1 = [startDate]) and splits them into "now" and "next". An activity
/// without an end time lasts its `durationSeconds`, or one hour. One that
/// ends before it starts is taken to end after midnight. Organizers can force
/// an activity into "now" with status `en_curso` (for that day) or out of it
/// with `realizado`.
CamporeeAgendaNow resolveCamporeeAgendaNow(
  List<CamporeeAgendaEntry> entries, {
  required DateTime startDate,
  required DateTime now,
}) {
  final slots = <CamporeeAgendaSlot>[];
  for (final entry in entries) {
    final event = entry.event;
    if (!event.agendaVisible || event.status == 'cancelado') continue;
    final startClock = formatCamporeeClock(entry.startsAt);
    if (startClock == null) continue;

    final day = camporeeAgendaDayDate(startDate, entry.dayNumber);
    final start = day.add(Duration(minutes: camporeeClockMinutes(startClock)));
    final endClock = formatCamporeeClock(entry.endsAt);
    DateTime end;
    if (endClock != null) {
      end = day.add(Duration(minutes: camporeeClockMinutes(endClock)));
      if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
    } else if ((event.durationSeconds ?? 0) > 0) {
      end = start.add(Duration(seconds: event.durationSeconds!));
    } else {
      end = start.add(kCamporeeDefaultActivityLength);
    }
    slots.add(CamporeeAgendaSlot(entry: entry, start: start, end: end));
  }

  final today = DateTime(now.year, now.month, now.day);
  bool isSameDay(DateTime value) =>
      value.year == today.year &&
      value.month == today.month &&
      value.day == today.day;

  final current = <CamporeeAgendaSlot>[];
  for (final slot in slots) {
    final status = slot.entry.event.status;
    if (status == 'realizado') continue;
    final running = !slot.start.isAfter(now) && slot.end.isAfter(now);
    final forced = status == 'en_curso' && isSameDay(slot.start);
    if (running || forced) current.add(slot);
  }

  final upcoming = [
    for (final slot in slots)
      if (slot.start.isAfter(now) && !current.contains(slot)) slot,
  ]..sort((a, b) => a.start.compareTo(b.start));
  final next = <CamporeeAgendaSlot>[
    for (final slot in upcoming)
      if (slot.start == upcoming.first.start) slot,
  ];

  current.sort((a, b) {
    final byStart = a.start.compareTo(b.start);
    return byStart != 0
        ? byStart
        : a.entry.headline.compareTo(b.entry.headline);
  });
  next.sort((a, b) => a.entry.headline.compareTo(b.entry.headline));
  return CamporeeAgendaNow(current: current, next: next);
}
