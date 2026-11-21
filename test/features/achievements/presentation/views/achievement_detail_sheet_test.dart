import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/animations/sac_rolling_number.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_state_panel.dart';
import 'package:sacdia_app/features/achievements/domain/entities/achievement.dart';
import 'package:sacdia_app/features/achievements/domain/entities/achievement_category.dart';
import 'package:sacdia_app/features/achievements/domain/entities/user_achievement.dart';
import 'package:sacdia_app/features/achievements/domain/repositories/achievements_repository.dart';
import 'package:sacdia_app/features/achievements/presentation/providers/achievements_providers.dart';
import 'package:sacdia_app/features/achievements/presentation/utils/achievement_dates.dart';
import 'package:sacdia_app/features/achievements/presentation/utils/achievement_progress_unit.dart';
import 'package:sacdia_app/features/achievements/presentation/views/achievement_detail_sheet.dart';
import 'package:sacdia_app/features/achievements/presentation/widgets/achievement_art.dart';
import 'package:sacdia_app/features/achievements/presentation/widgets/achievement_badge.dart';
import 'package:sacdia_app/features/achievements/presentation/widgets/achievement_hero_glow.dart';

import '../../../../support/l10n_test_support.dart';
import '../../../../support/riverpod_test_support.dart';

const _realBadge = 'https://example.com/fiel.png';

Achievement _streak({Map<String, dynamic>? criteria, int target = 4}) {
  return Achievement(
    achievementId: 7,
    categoryId: 1,
    name: 'Fiel',
    description: 'Asiste a actividades durante 4 semanas consecutivas.',
    badgeImageUrl: _realBadge,
    type: AchievementType.streak,
    tier: AchievementTier.silver,
    points: 30,
    criteria: criteria ??
        {
          'event': 'activity.attended',
          'operator': 'streak',
          'target': target,
          'streak_unit': 'week',
        },
  );
}

UserAchievement _progress(int value, {int target = 4}) {
  return UserAchievement(
    userAchievementId: 1,
    achievementId: 7,
    progressValue: value,
    progressTarget: target,
  );
}

UserAchievementsResponse _response(
  AchievementWithProgress item, {
  List<AchievementWithProgress> others = const [],
}) {
  return UserAchievementsResponse(
    summary: const UserAchievementsSummary(
      totalCompleted: 0,
      totalPoints: 0,
      completionPercentage: 0,
    ),
    categories: [
      UserAchievementCategoryGroup(
        category: const AchievementCategory(categoryId: 1, name: 'Dedicación'),
        achievements: [item, ...others],
      ),
    ],
  );
}

/// What the overridden provider serves next; the live-update test swaps it.
UserAchievementsResponse? _served;

void main() {
  setUpAll(loadSpanishTranslations);

  Future<ProviderContainer> pumpSheet(
    WidgetTester tester,
    AchievementWithProgress item, {
    bool followProvider = false,
    List<AchievementWithProgress> others = const [],
  }) async {
    await tester.pumpWidget(
      testProviderScope(
        overrides: [
          userAchievementsProvider.overrideWith(
            (ref) async =>
                (followProvider ? _served : null) ??
                _response(item, others: others),
          ),
        ],
        child: MediaQuery(
          data: const MediaQueryData(
            disableAnimations: true,
            size: Size(390, 844),
          ),
          child: MaterialApp(
            home: Scaffold(
              body: AchievementDetailSheet(achievementWithProgress: item),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return ProviderScope.containerOf(
      tester.element(find.byType(AchievementDetailSheet)),
    );
  }

  group('progress block', () {
    testWidgets('a weekly streak counts in weeks, not days', (tester) async {
      await pumpSheet(
        tester,
        AchievementWithProgress(
          achievement: _streak(),
          userAchievement: _progress(1),
        ),
      );

      expect(find.text('1 de 4'), findsOneWidget);
      expect(find.text('semanas'), findsOneWidget);
      expect(find.text('días'), findsNothing);
      expect(find.text('RACHA'), findsOneWidget);
    });

    testWidgets('shows ONE progress block, not progress plus streak',
        (tester) async {
      await pumpSheet(
        tester,
        AchievementWithProgress(
          achievement: _streak(),
          userAchievement: _progress(1),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('PROGRESO'), findsNothing);
      expect(find.textContaining('/ 4'), findsNothing);
      expect(find.textContaining('1/4'), findsNothing);
    });

    testWidgets('a non-streak achievement is labelled Progreso, with no unit',
        (tester) async {
      await pumpSheet(
        tester,
        AchievementWithProgress(
          achievement: const Achievement(
            achievementId: 7,
            categoryId: 1,
            name: 'Participante Activo',
            type: AchievementType.threshold,
            criteria: {'event': 'activity.attended', 'target': 10},
          ),
          userAchievement: _progress(6, target: 10),
        ),
      );

      expect(find.text('PROGRESO'), findsOneWidget);
      expect(find.text('RACHA'), findsNothing);
      expect(find.text('6 de 10'), findsOneWidget);
    });

    testWidgets('a streak without a period prints no unit', (tester) async {
      await pumpSheet(
        tester,
        AchievementWithProgress(
          achievement: _streak(criteria: {'target': 4}),
          userAchievement: _progress(1),
        ),
      );

      expect(find.text('1 de 4'), findsOneWidget);
      expect(find.text('días'), findsNothing);
      expect(find.text('semanas'), findsNothing);
      expect(find.text('meses'), findsNothing);
    });

    testWidgets('the bar uses the app accent and follows the progress',
        (tester) async {
      await pumpSheet(
        tester,
        AchievementWithProgress(
          achievement: _streak(),
          userAchievement: _progress(1),
        ),
      );

      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, closeTo(0.25, 0.001));
      expect(bar.color, isNotNull);
    });

    testWidgets('rolls the number and grows the bar when progress changes',
        (tester) async {
      final item = AchievementWithProgress(
        achievement: _streak(),
        userAchievement: _progress(1),
      );
      final container = await pumpSheet(tester, item, followProvider: true);

      expect(find.text('1 de 4'), findsOneWidget);

      _served = _response(
        AchievementWithProgress(
          achievement: _streak(),
          userAchievement: _progress(2),
        ),
      );
      container.invalidate(userAchievementsProvider);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('2 de 4'), findsOneWidget);
      expect(
        tester.widget<SacRollingNumber>(find.byType(SacRollingNumber)).value,
        2,
      );
      expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .value,
        closeTo(0.5, 0.001),
      );
    });
  });

  group('hero', () {
    testWidgets('an unobtained achievement shows its real badge in grey',
        (tester) async {
      await pumpSheet(
        tester,
        AchievementWithProgress(
          achievement: _streak(),
          userAchievement: _progress(1),
        ),
      );

      final art = tester.widget<AchievementArt>(find.byType(AchievementArt));
      expect(art.imageUrl, _realBadge);
      expect(
        find.ancestor(
          of: find.byType(AchievementArt),
          matching: find.byType(ColorFiltered),
        ),
        findsOneWidget,
      );
      // Not the generic "?" medal the sheet used to show.
      expect(find.byType(AchievementBadge), findsNothing);
    });

    testWidgets('an obtained achievement shows its real badge in colour',
        (tester) async {
      await pumpSheet(
        tester,
        AchievementWithProgress(
          achievement: _streak(),
          userAchievement: UserAchievement(
            userAchievementId: 1,
            achievementId: 7,
            progressValue: 4,
            progressTarget: 4,
            completed: true,
            completedAt: DateTime(2026, 9, 14),
          ),
        ),
      );

      final badge = tester.widget<AchievementBadge>(
        find.byType(AchievementBadge),
      );
      expect(badge.badgeImageUrl, _realBadge);
      expect(badge.visualState, AchievementVisualState.unlocked);
    });
  });

  group('obtained', () {
    testWidgets('replaces the progress block with a success panel and a date',
        (tester) async {
      final completedAt = DateTime(2026, 9, 14);
      await pumpSheet(
        tester,
        AchievementWithProgress(
          achievement: _streak(),
          userAchievement: UserAchievement(
            userAchievementId: 1,
            achievementId: 7,
            progressValue: 4,
            progressTarget: 4,
            completed: true,
            completedAt: completedAt,
          ),
        ),
      );

      expect(find.byType(SacStatePanel), findsOneWidget);
      expect(
        find.text('Obtenido el ${achievementLongDate(completedAt)}'),
        findsOneWidget,
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('RACHA'), findsNothing);
    });

    testWidgets(
        'wraps the badge in the tier halo and keeps it still with '
        'reduced motion', (tester) async {
      await pumpSheet(
        tester,
        AchievementWithProgress(
          achievement: _streak(),
          userAchievement: UserAchievement(
            userAchievementId: 1,
            achievementId: 7,
            progressValue: 4,
            progressTarget: 4,
            completed: true,
            completedAt: DateTime(2026, 9, 14),
          ),
        ),
      );

      final glow = tester.widget<AchievementHeroGlow>(
        find.byType(AchievementHeroGlow),
      );
      expect(glow.color, achievementTierColor(AchievementTier.silver));
      expect(
        find.descendant(
          of: find.byType(AchievementHeroGlow),
          matching: find.byType(AchievementBadge),
        ),
        findsOneWidget,
      );
      // Reduced motion: no pass of light is running.
      expect(
        find.descendant(
          of: find.byType(AchievementHeroGlow),
          matching: find.byType(ShaderMask),
        ),
        findsNothing,
      );
    });

    testWidgets('a badge not obtained yet has no halo', (tester) async {
      await pumpSheet(
        tester,
        AchievementWithProgress(achievement: _streak()),
      );

      expect(find.byType(AchievementHeroGlow), findsNothing);
    });
  });

  group('secret', () {
    testWidgets('shows the secret drawing, its tier and the reveal hint',
        (tester) async {
      await pumpSheet(
        tester,
        const AchievementWithProgress(
          achievement: Achievement(
            achievementId: 9,
            categoryId: 1,
            name: 'Leyenda Viviente',
            description: 'Obtén 10 honores y mantén una racha de 16 semanas.',
            tier: AchievementTier.diamond,
            points: 200,
            secret: true,
          ),
        ),
      );

      expect(find.byType(SecretBadgeArt), findsOneWidget);
      expect(find.text('Logro secreto'), findsOneWidget);
      expect(find.text('???'), findsNothing);
      expect(find.text('Leyenda Viviente'), findsNothing);
      expect(find.text('Diamante'), findsOneWidget);
      expect(find.text('200 puntos'), findsNothing);
      expect(
        find.text(
          'Se revela cuando lo consigas. Sigue participando en tu club.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Obtén 10 honores'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });

  group('locked', () {
    const pathfinder = Achievement(
      achievementId: 5,
      categoryId: 1,
      name: 'De Aventurero a Conquistador',
      tier: AchievementTier.gold,
      points: 60,
      prerequisiteId: 4,
    );
    const firstClass = Achievement(
      achievementId: 4,
      categoryId: 1,
      name: 'Aventurero Investido',
    );

    testWidgets('names the achievement that unlocks it, not its id',
        (tester) async {
      await pumpSheet(
        tester,
        const AchievementWithProgress(achievement: pathfinder),
        others: const [AchievementWithProgress(achievement: firstClass)],
      );

      expect(find.byType(SacStatePanel), findsOneWidget);
      expect(find.text('Bloqueado'), findsOneWidget);
      expect(
        find.text('Primero obtén «Aventurero Investido».'),
        findsOneWidget,
      );
      expect(find.textContaining('#4'), findsNothing);
    });

    testWidgets('a prerequisite the list does not have reads generically',
        (tester) async {
      await pumpSheet(
        tester,
        const AchievementWithProgress(achievement: pathfinder),
      );

      expect(find.text('Primero obtén otro logro.'), findsOneWidget);
    });

    testWidgets('an obtained prerequisite no longer locks it', (tester) async {
      await pumpSheet(
        tester,
        const AchievementWithProgress(achievement: pathfinder),
        others: const [
          AchievementWithProgress(
            achievement: firstClass,
            userAchievement: UserAchievement(
              userAchievementId: 2,
              achievementId: 4,
              completed: true,
            ),
          ),
        ],
      );

      expect(find.text('Bloqueado'), findsNothing);
      expect(find.text('Aún no lo obtienes'), findsOneWidget);
    });
  });

  group('not obtained', () {
    testWidgets('one with no count still says where the user stands',
        (tester) async {
      await pumpSheet(
        tester,
        const AchievementWithProgress(
          achievement: Achievement(
            achievementId: 8,
            categoryId: 1,
            name: 'Guía Mayor Investido',
          ),
        ),
      );

      expect(find.byType(SacStatePanel), findsOneWidget);
      expect(find.text('Aún no lo obtienes'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
    testWidgets('a one-off achievement does not count "0 de 1"',
        (tester) async {
      await pumpSheet(
        tester,
        const AchievementWithProgress(
          achievement: Achievement(
            achievementId: 8,
            categoryId: 1,
            name: 'Guía Mayor Investido',
            type: AchievementType.milestone,
            criteria: {'target': 1},
          ),
          userAchievement: UserAchievement(
            userAchievementId: 3,
            achievementId: 8,
            progressTarget: 1,
          ),
        ),
      );

      expect(find.text('Aún no lo obtienes'), findsOneWidget);
      expect(find.text('0 de 1'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });

  group('chips', () {
    testWidgets('show the tier and the points', (tester) async {
      await pumpSheet(
        tester,
        AchievementWithProgress(
          achievement: _streak(),
          userAchievement: _progress(1),
        ),
      );

      expect(find.text('Plata'), findsOneWidget);
      expect(find.text('30 puntos'), findsOneWidget);
    });
  });

  group('achievementUnitLabel', () {
    test('agrees in number with the count', () {
      loadSpanishTranslations();
      final week = _streak();
      expect(achievementUnitLabel(week, 1), 'semana');
      expect(achievementUnitLabel(week, 4), 'semanas');
    });

    test('reads day and month periods', () {
      loadSpanishTranslations();
      expect(
        achievementUnitLabel(_streak(criteria: {'streak_unit': 'day'}), 3),
        'días',
      );
      expect(
        achievementUnitLabel(_streak(criteria: {'streak_unit': 'month'}), 2),
        'meses',
      );
    });

    test('is null when the criteria carry no period', () {
      expect(achievementUnitLabel(_streak(criteria: {'target': 4}), 4), isNull);
      expect(
        achievementUnitLabel(
            _streak(criteria: {'streak_unit': 'fortnight'}), 4),
        isNull,
      );
    });
  });

  group('achievement dates', () {
    // The Spanish translations set the app locale (Intl.defaultLocale).
    final now = DateTime(2026, 11, 19);

    test('follow the app language and drop the current year', () {
      loadSpanishTranslations();
      expect(achievementShortDate(DateTime(2026, 9, 14), now: now), '14 sept');
      expect(
        achievementLongDate(DateTime(2026, 9, 14), now: now),
        '14 de septiembre',
      );
    });

    test('keep the year when it is not the current one', () {
      loadSpanishTranslations();
      expect(
        achievementShortDate(DateTime(2025, 9, 14), now: now),
        '14 sept 2025',
      );
      expect(
        achievementLongDate(DateTime(2025, 9, 14), now: now),
        '14 de septiembre de 2025',
      );
    });
  });
}
