import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/constants/certificate_dates.dart';

void main() {
  final now = DateTime(2026, 10, 12, 18, 30);

  CertificateDateIssue? check(DateTime? date, {bool mustHave = false}) =>
      CertificateDateRule.check(date, now: now, mustHave: mustHave);

  test('1959-12-31 is too old, 1960-01-01 is the first valid day', () {
    expect(check(DateTime(1959, 12, 31)), CertificateDateIssue.tooOld);
    expect(check(DateTime(1959, 12, 31, 23, 59)), CertificateDateIssue.tooOld);
    expect(check(DateTime(1960, 1, 1)), isNull);
  });

  test('today is valid at any hour, tomorrow is not', () {
    expect(check(DateTime(2026, 10, 12)), isNull);
    expect(check(DateTime(2026, 10, 12, 23, 59)), isNull);
    expect(check(DateTime(2026, 10, 13)), CertificateDateIssue.future);
  });

  test('a missing date is only an issue when it is required', () {
    expect(check(null), isNull);
    expect(check(null, mustHave: true), CertificateDateIssue.required);
  });

  test('lastDate is the calendar day of now', () {
    expect(CertificateDateRule.lastDate(now), DateTime(2026, 10, 12));
  });
}
