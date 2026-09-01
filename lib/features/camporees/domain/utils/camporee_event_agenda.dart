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
