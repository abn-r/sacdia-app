import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/achievements/domain/entities/achievement.dart';
import 'package:sacdia_app/features/achievements/domain/entities/user_achievement.dart';
import 'package:sacdia_app/features/achievements/domain/repositories/achievements_repository.dart';
import 'package:sacdia_app/features/achievements/presentation/views/achievement_detail_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> translations;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    translations = jsonDecode(
      await File('assets/translations/es.json').readAsString(),
    ) as Map<String, dynamic>;
  });

  Future<void> pumpSheet(
    WidgetTester tester,
    AchievementWithProgress item,
  ) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('es')],
        path: 'assets/translations',
        fallbackLocale: const Locale('es'),
        assetLoader: _TestAssetLoader(translations),
        child: Builder(
          builder: (context) => MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: Scaffold(
              body: AchievementDetailSheet(achievementWithProgress: item),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('in-progress shows remaining and NEXT block', (tester) async {
    await pumpSheet(
      tester,
      _item(
        name: 'Arrecife',
        user: const UserAchievement(
          userAchievementId: 12,
          achievementId: 12,
          progressValue: 2,
          progressTarget: 5,
        ),
      ),
    );

    expect(find.text('Arrecife'), findsOneWidget);
    expect(find.text('Faltan 3'), findsOneWidget);
    expect(find.text('SIGUIENTE'), findsOneWidget);
    expect(find.text('2 de 5'), findsOneWidget);
  });

  testWidgets('progressTarget <= 0 does not throw or show remaining',
      (tester) async {
    await pumpSheet(
      tester,
      _item(
        name: 'Broken Target',
        user: const UserAchievement(
          userAchievementId: 2,
          achievementId: 2,
          progressValue: 1,
          progressTarget: 0,
        ),
      ),
    );

    expect(find.text('Broken Target'), findsOneWidget);
    expect(find.textContaining('Faltan'), findsNothing);
    expect(find.text('SIGUIENTE'), findsOneWidget);
    expect(find.text('1 de —'), findsOneWidget);
  });

  testWidgets('secret in-progress hides remaining and NEXT', (tester) async {
    await pumpSheet(
      tester,
      _item(
        name: 'Hidden Secret',
        secret: true,
        user: const UserAchievement(
          userAchievementId: 9,
          achievementId: 9,
          progressValue: 2,
          progressTarget: 5,
        ),
      ),
    );

    expect(find.text('Hidden Secret'), findsNothing);
    expect(find.textContaining('Faltan'), findsNothing);
    expect(find.text('SIGUIENTE'), findsNothing);
    expect(find.text('achievements.views.detail_secret_hint'), findsNothing);
    expect(
      find.text('Sigue participando para descubrir este logro.'),
      findsOneWidget,
    );
  });

  testWidgets('completed does not show remaining or NEXT', (tester) async {
    await pumpSheet(
      tester,
      _item(
        name: 'Done',
        user: const UserAchievement(
          userAchievementId: 1,
          achievementId: 1,
          progressValue: 5,
          progressTarget: 5,
          completed: true,
        ),
      ),
    );

    expect(find.text('Done'), findsOneWidget);
    expect(find.textContaining('Faltan'), findsNothing);
    expect(find.text('SIGUIENTE'), findsNothing);
  });

  testWidgets('share CTA hidden while product defers share', (tester) async {
    await pumpSheet(
      tester,
      _item(
        name: 'Done',
        user: const UserAchievement(
          userAchievementId: 1,
          achievementId: 1,
          progressValue: 5,
          progressTarget: 5,
          completed: true,
        ),
      ),
    );

    expect(find.text('Compartir progreso'), findsNothing);
  });
}

AchievementWithProgress _item({
  required String name,
  required UserAchievement? user,
  bool secret = false,
}) {
  return AchievementWithProgress(
    achievement: Achievement(
      achievementId: user?.achievementId ?? 1,
      categoryId: 1,
      name: name,
      points: 300,
      secret: secret,
      description: secret ? null : 'Desc',
    ),
    userAchievement: user,
  );
}

class _TestAssetLoader extends AssetLoader {
  final Map<String, dynamic> translations;

  const _TestAssetLoader(this.translations);

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return translations;
  }
}
