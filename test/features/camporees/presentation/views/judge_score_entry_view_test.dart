import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_rubric.dart';
import 'package:sacdia_app/features/camporees/presentation/providers/camporees_providers.dart';
import 'package:sacdia_app/features/camporees/presentation/views/judge_score_entry_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('muestra identidad, stepper y total en la barra, no banner verde',
      (tester) async {
    await _pumpScoreEntry(tester);

    expect(find.text('Uniformidad QA app'), findsOneWidget);
    expect(find.text('ACV'), findsOneWidget);
    expect(find.text('Uniformidad'), findsOneWidget);
    expect(find.text('Total calculado: 0 / 100 puntos'), findsNothing);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('0 / 100'), findsOneWidget);
    expect(find.text('Enviar puntaje oficial'), findsOneWidget);
    expect(find.byType(SacButton), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('el stepper suma un punto y actualiza el total', (tester) async {
    await _pumpScoreEntry(tester);

    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is SacPressable &&
            widget.semanticLabel == 'Sumar puntos de Uniformidad',
      ),
    );
    await tester.pump();

    expect(find.text('1 / 100'), findsOneWidget);
    final field = tester.widget<TextField>(
      find.byType(TextField).first,
    );
    expect(field.controller?.text, '1');
  });
}

Future<void> _pumpScoreEntry(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        camporeeEventRubricsProvider.overrideWith(
          (ref, eventId) async => const [
            CamporeeRubric(
              rubricId: 1,
              eventId: 11,
              title: 'Uniformidad',
              maxPoints: 100,
              displayOrder: 1,
              active: true,
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
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  disableAnimations: true,
                ),
                child: child!,
              );
            },
            home: const JudgeScoreEntryView(
              eventId: 11,
              clubSectionId: 3,
              eventTitle: 'Uniformidad QA app',
              clubLabel: 'ACV',
            ),
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
