class MonthlyReportPeriod {
  final int month;
  final int year;

  const MonthlyReportPeriod({required this.month, required this.year});

  /// Period being prepared by directors/secretaries.
  ///
  /// During May, users are entering May data; the system/cron will generate
  /// the May report on the configured closing day in June.
  factory MonthlyReportPeriod.forPreparation([DateTime? now]) {
    final date = now ?? DateTime.now();
    return MonthlyReportPeriod(month: date.month, year: date.year);
  }
}
