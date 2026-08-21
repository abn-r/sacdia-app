import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';
import 'package:sacdia_app/features/support/presentation/views/support_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('should show search and each destination once', (tester) async {
    await _pumpSupport(tester);

    expect(find.text('Ayuda y soporte'), findsWidgets);
    expect(find.text('¿En qué podemos ayudarte?'), findsOneWidget);
    expect(find.text('Ruta de ayuda'), findsNothing);
    expect(find.text('Primera parada'), findsNothing);
    expect(find.text('Bitácora'), findsNothing);

    expect(find.byType(SacTextField), findsOneWidget);
    expect(find.text('Preguntas frecuentes'), findsOneWidget);
    expect(find.text('Contactar a soporte'), findsOneWidget);
    expect(find.text('Reportar un problema'), findsOneWidget);
  });
}

Future<void> _pumpSupport(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
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
            home: const SupportView(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    final file = File('$path/${locale.toLanguageTag()}.json');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
}
