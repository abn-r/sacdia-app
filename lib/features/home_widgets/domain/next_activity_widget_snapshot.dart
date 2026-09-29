import 'package:intl/intl.dart';

import '../../dashboard/domain/entities/dashboard_summary.dart';

/// Datos que el widget de inicio pinta. El texto ya llega traducido.
class NextActivityWidgetSnapshot {
  final bool hasActivity;
  final int? activityId;
  final String title;
  final String dateLabel;
  final String weekday;
  final String day;
  final String month;
  final String timeLabel;
  final String clubName;

  const NextActivityWidgetSnapshot({
    required this.hasActivity,
    required this.activityId,
    required this.title,
    required this.dateLabel,
    required this.weekday,
    required this.day,
    required this.month,
    required this.timeLabel,
    required this.clubName,
  });

  factory NextActivityWidgetSnapshot.empty({required String emptyTitle}) {
    return NextActivityWidgetSnapshot(
      hasActivity: false,
      activityId: null,
      title: emptyTitle,
      dateLabel: '',
      weekday: '',
      day: '',
      month: '',
      timeLabel: '',
      clubName: '',
    );
  }

  /// Usa la primera actividad del resumen. El dashboard ya la entrega ordenada.
  factory NextActivityWidgetSnapshot.fromSummary(
    DashboardSummary summary, {
    required String emptyTitle,
    String? localeName,
  }) {
    final clubName = (summary.clubName ?? '').trim();
    if (summary.upcomingActivities.isEmpty) {
      return NextActivityWidgetSnapshot(
        hasActivity: false,
        activityId: null,
        title: emptyTitle,
        dateLabel: '',
        weekday: '',
        day: '',
        month: '',
        timeLabel: '',
        clubName: clubName,
      );
    }

    final activity = summary.upcomingActivities.first;
    final parts = nextActivityDateParts(activity.activityDate, localeName);
    final timeLabel = activity.activityTime?.trim() ?? '';
    return NextActivityWidgetSnapshot(
      hasActivity: true,
      activityId: activity.id,
      title: activity.title.trim(),
      dateLabel: formatNextActivityDate(
        activity.activityDate,
        activity.activityTime,
        localeName,
      ),
      weekday: parts.weekday,
      day: parts.day,
      month: parts.month,
      timeLabel: timeLabel,
      clubName: clubName,
    );
  }
}

class NextActivityDateParts {
  final String weekday;
  final String day;
  final String month;

  const NextActivityDateParts({
    required this.weekday,
    required this.day,
    required this.month,
  });
}

NextActivityDateParts nextActivityDateParts(DateTime date, String? localeName) {
  try {
    return NextActivityDateParts(
      weekday: _compactDateToken(DateFormat('EEE', localeName).format(date)),
      day: DateFormat('d', localeName).format(date),
      month: _compactDateToken(DateFormat('MMM', localeName).format(date)),
    );
  } catch (_) {
    return NextActivityDateParts(
      weekday: '',
      day: '${date.day}',
      month: '${date.month}',
    );
  }
}

String _compactDateToken(String raw) {
  final cleaned = raw.replaceAll('.', '').trim();
  if (cleaned.isEmpty) return '';
  return cleaned.toUpperCase();
}

String formatNextActivityDate(
  DateTime date,
  String? time,
  String? localeName,
) {
  String formatted;
  try {
    formatted = DateFormat('EEE d MMM', localeName).format(date);
  } catch (_) {
    formatted = '${date.day}/${date.month}';
  }

  final clock = time?.trim();
  if (clock == null || clock.isEmpty) return formatted;
  return '$formatted · $clock';
}
