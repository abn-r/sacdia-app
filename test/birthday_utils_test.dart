import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/utils/birthday_utils.dart';

void main() {
  group('birthday utils', () {
    test('matches birthday by local calendar month and day only', () {
      final today = DateTime(2026, 6, 3, 12);

      expect(isBirthdayToday(DateTime(2000, 6, 3), today: today), isTrue);
      expect(isBirthdayToday(DateTime(2000, 6, 4), today: today), isFalse);
    });

    test('builds dismissal key scoped to user, current year, and birthday day',
        () {
      expect(
        birthdayDismissalKey(
          userId: 'user-1',
          birthday: DateTime(2000, 6, 3),
          today: DateTime(2026, 6, 3),
        ),
        'sacdia:birthday:user-1:2026:06-03',
      );
    });

    test('returns null key when user or birthday is missing', () {
      expect(
        birthdayDismissalKey(userId: null, birthday: DateTime(2000, 6, 3)),
        isNull,
      );
      expect(birthdayDismissalKey(userId: 'user-1', birthday: null), isNull);
    });

    test('calculates duration until next local day', () {
      expect(
        durationUntilNextLocalDay(DateTime(2026, 6, 3, 23, 30)),
        const Duration(minutes: 30),
      );
    });
  });
}
