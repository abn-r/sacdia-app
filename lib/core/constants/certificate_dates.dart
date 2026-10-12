/// Earliest date accepted for a completed honor or a class investiture
/// (D6). The backend enforces the same floor; keep both in sync.
final DateTime kMinCertificateDate = DateTime(1960, 1, 1);

/// Why a completion or investiture date cannot be used.
enum CertificateDateIssue { required, tooOld, future }

/// Single date rule for honors and classes (D6): from 1960-01-01 up to today.
abstract final class CertificateDateRule {
  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Latest valid day. [now] is injectable for tests.
  static DateTime lastDate([DateTime? now]) => _day(now ?? DateTime.now());

  /// Null when [date] is valid; [required] only matters if [mustHave].
  static CertificateDateIssue? check(
    DateTime? date, {
    bool mustHave = false,
    DateTime? now,
  }) {
    if (date == null) return mustHave ? CertificateDateIssue.required : null;
    final day = _day(date);
    if (day.isBefore(kMinCertificateDate)) return CertificateDateIssue.tooOld;
    if (day.isAfter(lastDate(now))) return CertificateDateIssue.future;
    return null;
  }
}
