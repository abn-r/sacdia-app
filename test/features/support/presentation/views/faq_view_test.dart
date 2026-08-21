import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/features/support/domain/entities/faq_item.dart';
import 'package:sacdia_app/features/support/presentation/providers/support_providers.dart';
import 'package:sacdia_app/features/support/presentation/views/faq_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('should expand an answer on tap', (tester) async {
    await _pumpFaq(tester);

    expect(find.text('¿Cómo inicio sesión?'), findsOneWidget);
    expect(find.text('Con tu correo institucional.'), findsNothing);

    await tester.tap(find.text('¿Cómo inicio sesión?'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.text('Con tu correo institucional.'), findsOneWidget);
  });

  testWidgets('should filter questions from the search field', (tester) async {
    await _pumpFaq(tester);

    await tester.enterText(find.byType(TextFormField), 'internet');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('¿Cómo inicio sesión?'), findsNothing);
    expect(find.text('¿Funciona sin internet?'), findsOneWidget);
  });
}

Future<void> _pumpFaq(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        faqItemsProvider.overrideWith(
          (ref) async => const [
            FaqItem(
              id: 'login',
              category: 'account',
              question: '¿Cómo inicio sesión?',
              answer: 'Con tu correo institucional.',
            ),
            FaqItem(
              id: 'offline',
              category: 'offline',
              question: '¿Funciona sin internet?',
              answer: 'Parte del contenido queda disponible.',
            ),
          ],
        ),
      ],
      child: EasyLocalization(
        supportedLocales: const [Locale('es')],
        path: 'assets/translations',
        assetLoader: const _FileAssetLoader(),
        fallbackLocale: const Locale('es'),
        startLocale: const Locale('es'),
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.lightTheme,
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            home: const FaqView(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 80));
}

class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    final file = File('$path/${locale.toLanguageTag()}.json');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
}
