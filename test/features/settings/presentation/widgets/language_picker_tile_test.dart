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
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
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
