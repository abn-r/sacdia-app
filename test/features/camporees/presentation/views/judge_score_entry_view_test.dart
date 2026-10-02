import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_official_score.dart';
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
    expect(find.text('Total:'), findsOneWidget);
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
    expect(find.text('El puntaje mínimo es de 0'), findsNothing);
    final field = tester.widget<TextField>(
      find.byType(TextField).first,
    );
    expect(field.controller?.text, '1');
  });

  testWidgets('el mínimo del evento sube el total cuando la suma queda debajo',
      (tester) async {
    await _pumpScoreEntry(tester, minPoints: 40);

    expect(find.text('0 / 100'), findsNothing);
    expect(find.text('40 / 100'), findsOneWidget);
    expect(find.text('El puntaje mínimo es de 40'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '50');
    await tester.pump();

    expect(find.text('50 / 100'), findsOneWidget);
    expect(find.text('El puntaje mínimo es de 40'), findsOneWidget);
  });

  testWidgets('el botón de envío cabe completo junto al mínimo', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpScoreEntry(tester, minPoints: 40);

    final button = tester.getRect(find.byType(SacButton));
    final hint = tester.getRect(find.text('El puntaje mínimo es de 40'));
    expect(button.left, greaterThanOrEqualTo(16));
    expect(button.right, lessThanOrEqualTo(390 - 16));
    expect(button.width, greaterThan(300));
    expect(hint.right, lessThanOrEqualTo(390 - 16));
    expect(hint.bottom, lessThanOrEqualTo(button.top));
  });

  testWidgets('un puntaje existente muestra el detalle y no permite reenviar',
      (tester) async {
    await _pumpScoreEntry(
      tester,
      officialScore: CamporeeOfficialScore(
        resultId: 'result-1',
        scoreStatus: 'scored',
        isNoShow: false,
        totalAwarded: 40,
        totalMax: 100,
        rawAwarded: 17,
        minimumAdjustment: 23,
        evaluatorName: 'Ana López',
        notes: 'sin comentarios',
        items: const [
          CamporeeOfficialScoreItem(
            rubricId: 7,
            title: 'Criterio A - Presentación',
            awardedPoints: 0,
            maxPoints: 20,
          ),
          CamporeeOfficialScoreItem(
            rubricId: 8,
            title: 'Criterio B - Ejecución técnica',
            awardedPoints: 5,
            maxPoints: 30,
          ),
        ],
      ),
    );

    expect(find.text('Puntaje oficial'), findsOneWidget);
    expect(find.text('Ana López'), findsOneWidget);
    expect(find.text('Criterio B - Ejecución técnica'), findsOneWidget);
    expect(find.text('5 / 30'), findsOneWidget);
    expect(find.text('sin comentarios'), findsOneWidget);
    expect(find.text('Enviar puntaje oficial'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });
}

Future<void> _pumpScoreEntry(
  WidgetTester tester, {
  double minPoints = 0,
  CamporeeOfficialScore? officialScore,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        camporeeOfficialScoreProvider.overrideWith(
          (ref, params) async => officialScore,
        ),
        camporeeEventRubricsProvider.overrideWith(
          (ref, eventId) async => CamporeeEventRubricSheet(
            minPoints: minPoints,
            rubrics: const [
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
