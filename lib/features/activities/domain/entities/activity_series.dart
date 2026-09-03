class ActivitySeriesPreview {
  final int count;
  final List<String> dates;
  final String until;

  const ActivitySeriesPreview({
    required this.count,
    required this.dates,
    required this.until,
  });
}

class ActivitySeriesCounts {
  final int total;
  final int active;
  final int upcoming;
  final int past;

  const ActivitySeriesCounts({
    required this.total,
    required this.active,
    required this.upcoming,
    required this.past,
  });
}

class ActivitySeriesSummary {
  final int id;
  final String name;
  final String kind;
  final int? intervalDays;
  final List<int> weekdays;
  final String firstDate;
  final String untilDate;
  final ActivitySeriesCounts? counts;

  const ActivitySeriesSummary({
    required this.id,
    required this.name,
    required this.kind,
    this.intervalDays,
    this.weekdays = const [],
    required this.firstDate,
    required this.untilDate,
    this.counts,
  });
}

class CreateActivitySeriesResult {
  final int seriesId;
  final int createdCount;
  final List<int> activityIds;

  const CreateActivitySeriesResult({
    required this.seriesId,
    required this.createdCount,
    required this.activityIds,
  });
}
