import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/profile/domain/entities/notification_preferences.dart';

/// The backend derives `master` as the AND of the five categories, so
/// turning one category off reports master=false. The settings switches
/// must not treat that as "push disabled" or every category locks.
void main() {
  test('one category off still leaves the categories enabled', () {
    const prefs = NotificationPreferences(
      master: false,
      activities: true,
      achievements: true,
      approvals: true,
      invitations: true,
      reminders: false,
    );

    expect(prefs.anyCategoryEnabled, isTrue);
  });

  test('all categories off means push is off', () {
    const prefs = NotificationPreferences(
      master: false,
      activities: false,
      achievements: false,
      approvals: false,
      invitations: false,
      reminders: false,
    );

    expect(prefs.anyCategoryEnabled, isFalse);
  });

  test('master in a delta cascades to every category', () {
    const prefs = NotificationPreferences.defaults();

    final off = prefs.applyDelta({'master': false});
    expect(off.anyCategoryEnabled, isFalse);
    expect(off.master, isFalse);

    final on = off.applyDelta({'master': true});
    expect(on, const NotificationPreferences.defaults());
  });

  test('a single category delta only changes that category', () {
    const prefs = NotificationPreferences.defaults();

    final next = prefs.applyDelta({'reminders': false});

    expect(next.reminders, isFalse);
    expect(next.activities, isTrue);
    expect(next.anyCategoryEnabled, isTrue);
  });
}
