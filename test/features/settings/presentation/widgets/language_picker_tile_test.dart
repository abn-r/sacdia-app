import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/features/settings/presentation/widgets/language_picker_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoTranslations extends AssetLoader {
  const _NoTranslations();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async => {};
}

/// The flag stripes are childless boxes inside a Row. With the default
/// center cross-axis alignment they collapsed to 0px tall, so the badge
/// rendered as an empty white box with white text.
Future<void> _pumpTile(WidgetTester tester) async {
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('es')],
      path: 'assets/translations',
      assetLoader: const _NoTranslations(),
      fallbackLocale: const Locale('es'),
      startLocale: const Locale('es'),
      child: Builder(
        builder: (context) => MaterialApp(
          theme: AppTheme.lightTheme,
          locale: context.locale,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          home: const Scaffold(body: LanguagePickerTile()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Color? _codeColor(WidgetTester tester, String code) =>
    tester.widget<Text>(find.text(code).last).style?.color;

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  // English and French have a white middle stripe: their code must be dark or
  // the badge reads as an unlabeled tricolour (English looked like France).
  testWidgets('codes on a white middle stripe are dark, the rest white',
      (tester) async {
    // Phone-sized surface: the default 800x600 test view is too short for the
    // four-language sheet.
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTile(tester);
    await tester.tap(find.byType(LanguagePickerTile));
    await tester.pumpAndSettle();

    const dark = Color(0xFF111827);
    expect(_codeColor(tester, 'EN'), dark);
    expect(_codeColor(tester, 'FR'), dark);
    expect(_codeColor(tester, 'ES'), Colors.white);
    expect(_codeColor(tester, 'BR'), Colors.white);
  });

  testWidgets('the Spanish flag stripes fill the badge height', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('es')],
        path: 'assets/translations',
        assetLoader: const _NoTranslations(),
        fallbackLocale: const Locale('es'),
        startLocale: const Locale('es'),
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.lightTheme,
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            home: const Scaffold(body: LanguagePickerTile()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final stripes = find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).color == const Color(0xFFF1BF00),
    );

    expect(stripes, findsOneWidget);
    expect(tester.getSize(stripes).height, greaterThan(0));
  });
}
