import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/theme/accent_provider.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/theme_provider.dart';
import 'package:sacdia_app/features/accessibility/domain/entities/accessibility_settings.dart';
import 'package:sacdia_app/features/accessibility/presentation/providers/accessibility_provider.dart';
import 'package:sacdia_app/features/settings/presentation/views/appearance_view.dart';
import 'package:sacdia_app/providers/storage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../family/family_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initLocalization);

  Future<ProviderContainer> pump(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpFamilyApp(
      tester,
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      routes: [
        GoRoute(path: '/', builder: (_, __) => const AppearanceView()),
      ],
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(AppearanceView)),
    );
  }

  testWidgets('shows theme, accent and text sections with real content',
      (tester) async {
    await pump(tester);

    expect(find.text('settings.appearance_title'.tr()), findsOneWidget);
    for (final key in [
      'settings.appearance.section_theme',
      'settings.appearance.section_accent',
      'settings.appearance.section_text',
    ]) {
      expect(find.text(key.tr().toUpperCase()), findsOneWidget, reason: key);
    }
    expect(
      find.text('settings.appearance.sample_text'.tr()),
      findsOneWidget,
    );
    expect(find.text('accessibility.high_contrast_tile'.tr()), findsOneWidget);
    expect(find.text('accessibility.reduce_motion_tile'.tr()), findsOneWidget);
    // Nada de «Lorem ipsum».
    expect(find.textContaining('Lorem'), findsNothing);
  });

  testWidgets('choosing a theme card applies it at once', (tester) async {
    final container = await pump(tester);
    expect(container.read(themeNotifierProvider), ThemeMode.system);

    await tester.tap(find.byKey(const ValueKey('theme-card-dark')));
    await tester.pumpAndSettle();
    expect(container.read(themeNotifierProvider), ThemeMode.dark);

    await tester.tap(find.byKey(const ValueKey('theme-card-light')));
    await tester.pumpAndSettle();
    expect(container.read(themeNotifierProvider), ThemeMode.light);
  });

  testWidgets('choosing a swatch applies the accent and names it',
      (tester) async {
    final container = await pump(tester);
    expect(container.read(accentNotifierProvider).id, SacAccent.logoBlue.id);
    // The eyebrow shows the chosen accent name.
    expect(find.text(SacAccent.logoBlue.labelKey.tr()), findsWidgets);

    await tester.tap(find.byKey(ValueKey('accent-${SacAccent.coral.id}')));
    await tester.pumpAndSettle();

    expect(container.read(accentNotifierProvider).id, SacAccent.coral.id);
    expect(find.text(SacAccent.coral.labelKey.tr()), findsWidgets);
  });

  testWidgets('every accent of the catalog has a swatch', (tester) async {
    await pump(tester);

    for (final accent in SacAccent.catalog) {
      expect(
        find.byKey(ValueKey('accent-${accent.id}')),
        findsOneWidget,
        reason: accent.id,
      );
    }
  });

  testWidgets('the slider sets the text size, the switches the toggles',
      (tester) async {
    final container = await pump(tester);
    expect(
      container.read(accessibilityProvider).textSize,
      TextSizeOption.system,
    );

    await tester.drag(find.byType(Slider), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(
      container.read(accessibilityProvider).textSize,
      TextSizeOption.extraLarge,
    );

    await tester.tap(find.text('accessibility.high_contrast_tile'.tr()));
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(container.read(accessibilityProvider).highContrast, isTrue);

    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    expect(container.read(accessibilityProvider).reduceMotion, isTrue);
  });
}
