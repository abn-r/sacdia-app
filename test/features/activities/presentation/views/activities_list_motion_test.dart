import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';
import 'package:sacdia_app/features/activities/domain/entities/activity.dart';
import 'package:sacdia_app/features/activities/presentation/providers/activities_providers.dart';
import 'package:sacdia_app/features/activities/presentation/views/activities_list_view.dart';
import 'package:sacdia_app/features/activities/presentation/widgets/activity_card.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<UserEntity?> build() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> translations;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('es');
    await EasyLocalization.ensureInitialized();
    translations = jsonDecode(
      await File('assets/translations/es.json').readAsString(),
    ) as Map<String, dynamic>;
  });

  Activity buildActivity() {
    final today = DateTime.now();
    return Activity(
      id: 11,
      name: 'Actividad visible',
      activityPlace: 'Parque central',
      activityType: 1,
      platform: 0,
      active: true,
      clubSectionId: 2,
      clubTypeId: 3,
      activityDate: DateTime(today.year, today.month, today.day),
    );
  }

  Widget localizedTestApp(Widget home) {
    return EasyLocalization(
      supportedLocales: const [Locale('es')],
      path: 'assets/translations',
      fallbackLocale: const Locale('es'),
      assetLoader: _TestAssetLoader(translations),
      child: Builder(
        builder: (context) => MaterialApp(
          locale: context.locale,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          home: home,
        ),
      ),
    );
  }

  Future<void> pumpActivitiesList(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final activity = buildActivity();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
          clubActivitiesProvider.overrideWith(
            (ref, params) async => [activity],
          ),
        ],
        child: localizedTestApp(const ActivitiesListView(clubId: 1)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('does not add an entrance scale to an activity card',
      (tester) async {
    await tester.pumpWidget(
      localizedTestApp(
        Scaffold(
          body: ActivityCard(
            activity: buildActivity(),
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(ActivityCard),
        matching: find.byType(ScaleTransition),
      ),
      findsNothing,
    );
  });

  testWidgets('builds activity rows without staggered slide or scale entrances',
      (tester) async {
    await pumpActivitiesList(tester);

    expect(find.byType(ActivityCard), findsOneWidget);
    expect(find.byType(StaggeredListItem), findsNothing);
    final activityList = find.ancestor(
      of: find.byType(ActivityCard),
      matching: find.byType(ListView),
    );
    expect(activityList, findsOneWidget);
    expect(
      find.descendant(
        of: activityList,
        matching: find.byType(SlideTransition),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(ActivityCard),
        matching: find.byType(ScaleTransition),
      ),
      findsNothing,
    );
  });

  testWidgets('switches list modes with one standard ease-out fade only',
      (tester) async {
    await pumpActivitiesList(tester);

    final modeSwitcher = find.descendant(
      of: find.byType(ActivitiesListView),
      matching: find.byType(AnimatedSwitcher),
    );
    expect(modeSwitcher, findsOneWidget);

    final switcher = tester.widget<AnimatedSwitcher>(modeSwitcher);
    expect(switcher.duration, SacMotion.standard);
    expect(switcher.switchInCurve, SacMotion.easeOut);
    expect(switcher.switchOutCurve, SacMotion.easeOut);

    final modeToggle = find.byWidgetPredicate(
      (widget) =>
          widget is HugeIcon && widget.icon == HugeIcons.strokeRoundedListView,
    );
    await tester.tap(modeToggle);
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('uses a pure fade while replacing the visible list mode',
      (tester) async {
    await pumpActivitiesList(tester);

    final modeToggle = find.byWidgetPredicate(
      (widget) =>
          widget is HugeIcon && widget.icon == HugeIcons.strokeRoundedListView,
    );
    expect(modeToggle, findsOneWidget);
    await tester.tap(modeToggle);
    await tester.pump(const Duration(milliseconds: 100));

    final modeSwitcher = find.descendant(
      of: find.byType(ActivitiesListView),
      matching: find.byType(AnimatedSwitcher),
    );
    expect(modeSwitcher, findsOneWidget);
    expect(find.byType(ActivityCard), findsWidgets);
    expect(find.byType(StaggeredListItem), findsNothing);
    expect(
      find.descendant(
        of: modeSwitcher,
        matching: find.byType(FadeTransition),
      ),
      findsWidgets,
    );
    expect(
      find.descendant(
        of: modeSwitcher,
        matching: find.byType(SlideTransition),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: modeSwitcher,
        matching: find.byType(ScaleTransition),
      ),
      findsNothing,
    );
  });
}

class _TestAssetLoader extends AssetLoader {
  const _TestAssetLoader(this.translations);

  final Map<String, dynamic> translations;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return translations;
  }
}
