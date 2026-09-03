/// Recurrence recipe for creating an activity series.
class RecurrenceRule {
  final String kind;
  final int? intervalDays;
  final List<int>? weekdays;
  final DateTime? until;

  const RecurrenceRule({
    required this.kind,
    this.intervalDays,
    this.weekdays,
    this.until,
  });

  factory RecurrenceRule.weekly({
    required int weekday,
    DateTime? until,
  }) {
    return RecurrenceRule(
      kind: 'weekly',
      weekdays: [weekday],
      until: until,
    );
  }

  factory RecurrenceRule.interval({
    required int days,
    DateTime? until,
  }) {
    return RecurrenceRule(
      kind: 'interval',
      intervalDays: days,
      until: until,
    );
  }

  Map<String, dynamic> toJson(String Function(DateTime) formatDate) {
    final json = <String, dynamic>{'kind': kind};
    if (kind == 'interval' && intervalDays != null) {
      json['interval_days'] = intervalDays;
    }
    if (kind == 'weekly' && weekdays != null && weekdays!.isNotEmpty) {
      json['weekdays'] = weekdays;
    }
    if (until != null) {
      json['until'] = formatDate(until!);
    }
    return json;
  }
}
