import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/achievements/presentation/utils/achievement_share_text.dart';

void main() {
  const template =
      'I unlocked {name} ({tier}) — {points} pts on SACDIA';

  test('includes name, tier, and points for completed achievement', () {
    final text = buildAchievementShareText(
      template: template,
      name: 'First Treasure',
      tier: 'Gold',
      points: 300,
    );

    expect(text, contains('First Treasure'));
    expect(text, contains('Gold'));
    expect(text, contains('300'));
    expect(text, isNot(contains('null')));
  });

  test('null completedOn does not produce null literal', () {
    final text = buildAchievementShareText(
      template: 'Unlocked {name} on {completedOn} — {points} pts',
      name: 'Explorer',
      tier: 'Bronze',
      points: 50,
      completedOn: null,
    );

    expect(text, isNot(contains('null')));
    expect(text, contains('Explorer'));
    expect(text, contains('50'));
  });

  test('empty completedOn is omitted cleanly', () {
    final text = buildAchievementShareText(
      template: 'Unlocked {name} on {completedOn} — {points} pts',
      name: 'Explorer',
      tier: 'Bronze',
      points: 50,
      completedOn: '',
    );

    expect(text, isNot(contains('null')));
    expect(text.contains('  '), isFalse);
  });

  test('secret path is caller responsibility — empty name stays empty', () {
    // Formatter does not invent titles; caller must not share secret-masked items.
    final text = buildAchievementShareText(
      template: template,
      name: '',
      tier: 'Silver',
      points: 10,
    );
    expect(text, contains('Silver'));
    expect(text, isNot(contains('null')));
  });
}
