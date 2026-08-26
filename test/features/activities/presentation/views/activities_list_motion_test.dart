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

  const cardModeKey = ValueKey('card');
  const chronologicalModeKey = ValueKey('chrono');
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

  Finder activitiesSwitcher() => find.descendant(
        of: find.byType(ActivitiesListView),
        matching: find.byType(AnimatedSwitcher),
      );

  Finder modeChild(Finder switcher, Key key) => find.descendant(
        of: switcher,
        matching: find.byKey(key),
      );

  double modeOpacity(
    WidgetTester tester,
    Finder switcher,
    Key key,
  ) {
    final child = modeChild(switcher, key);
    expect(child, findsOneWidget);

    final fade =
        tester.element(child).findAncestorWidgetOfExactType<FadeTransition>();
    expect(fade, isNotNull);
    expect(
      find.descendant(
        of: switcher,
        matching: find.byWidget(fade!),
      ),
      findsOneWidget,
    );
    return fade.opacity.value;
  }

  /// Press [AnimatedScale] on tappable cards uses [ScaleTransition] internally.
  /// Entrance motion is a [ScaleTransition] that is not under [AnimatedScale].
  void expectNoEntranceScale(Finder root) {
    final entranceScales = find
        .descendant(
          of: root,
          matching: find.byType(ScaleTransition),
        )
        .evaluate()
        .where(
          (element) =>
              element.findAncestorWidgetOfExactType<AnimatedScale>() == null,
        );
    expect(entranceScales, isEmpty);
  }

  void expectNoPositionalOrScaleMotion(Finder switcher) {
    expect(
      find.descendant(
        of: switcher,
        matching: find.byType(SlideTransition),
      ),
      findsNothing,
    );
    expectNoEntranceScale(switcher);
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

    expectNoEntranceScale(find.byType(ActivityCard));
  });

  testWidgets('builds activity rows without staggered slide or scale entrances',
      (tester) async {
    await pumpActivitiesList(tester);

    expect(find.byType(ActivityCard), findsOneWidget);
    final activityList = find.ancestor(
      of: find.byType(ActivityCard),
      matching: find.byType(ListView),
    );
    expect(activityList, findsOneWidget);
    expect(
      find.descendant(
        of: activityList,
        matching: find.byType(StaggeredListItem),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: activityList,
        matching: find.byType(SlideTransition),
      ),
      findsNothing,
    );
    expectNoEntranceScale(find.byType(ActivityCard));
  });

  testWidgets('replaces card mode with one standard ease-out fade',
      (tester) async {
    await pumpActivitiesList(tester);

    final modeSwitcher = activitiesSwitcher();
    expect(modeSwitcher, findsOneWidget);

    var switcher = tester.widget<AnimatedSwitcher>(modeSwitcher);
    expect(switcher.child?.key, cardModeKey);
    expect(modeChild(modeSwitcher, cardModeKey), findsOneWidget);
    expect(modeChild(modeSwitcher, chronologicalModeKey), findsNothing);
    expect(switcher.duration, SacMotion.standard);
    expect(switcher.switchInCurve, SacMotion.easeOut);
    expect(switcher.switchOutCurve, SacMotion.easeOut);

    final modeToggle = find.byWidgetPredicate(
      (widget) =>
          widget is HugeIcon && widget.icon == HugeIcons.strokeRoundedListView,
    );
    await tester.tap(modeToggle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    switcher = tester.widget<AnimatedSwitcher>(modeSwitcher);
    expect(switcher.child?.key, chronologicalModeKey);
    expect(modeChild(modeSwitcher, cardModeKey), findsOneWidget);
    expect(modeChild(modeSwitcher, chronologicalModeKey), findsOneWidget);
    expect(
      modeOpacity(tester, modeSwitcher, cardModeKey),
      allOf(greaterThan(0), lessThan(1)),
    );
    expect(
      modeOpacity(tester, modeSwitcher, chronologicalModeKey),
      allOf(greaterThan(0), lessThan(1)),
    );
    expectNoPositionalOrScaleMotion(modeSwitcher);

    await tester.pumpAndSettle();

    switcher = tester.widget<AnimatedSwitcher>(modeSwitcher);
    expect(switcher.child?.key, chronologicalModeKey);
    expect(modeChild(modeSwitcher, cardModeKey), findsNothing);
    expect(modeChild(modeSwitcher, chronologicalModeKey), findsOneWidget);
  });

  testWidgets(
      'rapid retarget settles back on card mode without residual motion',
      (tester) async {
    await pumpActivitiesList(tester);

    final modeSwitcher = activitiesSwitcher();
    final modeToggle = find.byWidgetPredicate(
      (widget) =>
          widget is HugeIcon && widget.icon == HugeIcons.strokeRoundedListView,
    );
    expect(modeToggle, findsOneWidget);
    final toggleCenter = tester.getCenter(modeToggle);

    await tester.tapAt(toggleCenter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(modeChild(modeSwitcher, cardModeKey), findsOneWidget);
    expect(modeChild(modeSwitcher, chronologicalModeKey), findsOneWidget);

    await tester.tapAt(toggleCenter);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(modeSwitcher, findsOneWidget);
    expect(
      tester.widget<AnimatedSwitcher>(modeSwitcher).child?.key,
      cardModeKey,
    );
    expect(modeChild(modeSwitcher, cardModeKey), findsOneWidget);
    expect(modeChild(modeSwitcher, chronologicalModeKey), findsNothing);
    expect(
      find.descendant(
        of: modeSwitcher,
        matching: find.byType(ActivityCard),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: modeSwitcher,
        matching: find.byType(StaggeredListItem),
      ),
      findsNothing,
    );
    expectNoPositionalOrScaleMotion(modeSwitcher);
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
