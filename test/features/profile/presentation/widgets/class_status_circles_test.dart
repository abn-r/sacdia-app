import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/classes/domain/entities/progressive_class.dart';
import 'package:sacdia_app/features/classes/presentation/providers/classes_providers.dart';
import 'package:sacdia_app/features/investiture/domain/entities/investiture_history_entry.dart';
import 'package:sacdia_app/features/investiture/presentation/providers/investiture_providers.dart';
import 'package:sacdia_app/features/profile/presentation/widgets/class_status_circles.dart';
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

  Future<void> pumpCircles(
    WidgetTester tester, {
    List<ProgressiveClass>? classes,
    Completer<List<ProgressiveClass>>? loadingCompleter,
    List<Override> extraOverrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userClassesProvider.overrideWith((ref) {
            if (loadingCompleter != null) {
              return loadingCompleter.future;
            }
            return Future.value(classes ?? <ProgressiveClass>[]);
          }),
          ...extraOverrides,
        ],
        child: EasyLocalization(
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
              home: const Scaffold(
                body: ClassStatusCircles(clubType: 'Conquistadores'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows circle skeleton while loading', (tester) async {
    final completer = Completer<List<ProgressiveClass>>();
    addTearDown(() {
      if (!completer.isCompleted) {
        completer.complete(const []);
      }
    });

    await pumpCircles(tester, loadingCompleter: completer);
    await tester.pump();

    expect(find.byKey(const ValueKey('class_circles_loading')), findsOneWidget);
    expect(find.text('Guía'), findsNothing);
    expect(find.text('Amigo'), findsNothing);
  });

  testWidgets('hides class names under circles when loaded', (tester) async {
    await pumpCircles(
      tester,
      classes: const [
        ProgressiveClass(
          id: 6,
          name: 'Guía',
          clubTypeId: 1,
          investitureStatus: 'INVESTIDO',
          overallProgress: 100,
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('class_circles_loading')), findsNothing);
    expect(find.text('Guía'), findsNothing);
    expect(find.text('Amigo'), findsNothing);
    expect(find.text('Compañero'), findsNothing);
  });

  testWidgets('tap invested circle opens sheet with invested details',
      (tester) async {
    await pumpCircles(
      tester,
      classes: [
        ProgressiveClass(
          id: 6,
          name: 'Guía',
          clubTypeId: 1,
          enrollmentId: 42,
          investitureStatus: 'INVESTIDO',
          overallProgress: 100,
          description: 'Clase superior',
          enrollmentDate: DateTime(2025, 3, 1, 12),
          submittedAt: DateTime(2025, 10, 15, 12),
          validatedAt: DateTime(2025, 11, 20, 12),
          ecclesiasticalYearLabel: '2025–2026',
        ),
      ],
      extraOverrides: [
        investitureHistoryProvider(42).overrideWith(
          (ref) async => [
            InvestitureHistoryEntry(
              id: 1,
              action: InvestitureAction.invested,
              performedAt: DateTime(2025, 12, 5, 12),
              performerName: 'Director',
            ),
          ],
        ),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Guía'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Guía'), findsOneWidget);
    expect(find.text('Investido'), findsWidgets);
    expect(find.text('Estado'), findsOneWidget);
    expect(find.text('Progreso'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Año eclesiástico'), findsOneWidget);
    expect(find.text('2025–2026'), findsOneWidget);
    expect(find.text('Inscripción'), findsOneWidget);
    expect(find.text('01/03/2025'), findsOneWidget);
    expect(find.text('Enviado a validación'), findsOneWidget);
    expect(find.text('15/10/2025'), findsOneWidget);
    expect(find.text('Validación'), findsOneWidget);
    expect(find.text('20/11/2025'), findsOneWidget);
    expect(find.text('Investidura'), findsOneWidget);
    expect(find.text('05/12/2025'), findsOneWidget);
    expect(find.text('Progreso: 100%'), findsNothing);
    expect(find.text('Clase superior'), findsOneWidget);
    expect(
      find.text('Aún no has completado esta clase.'),
      findsNothing,
    );
  });

  testWidgets('invested sheet omits missing investiture fields', (tester) async {
    await pumpCircles(
      tester,
      classes: const [
        ProgressiveClass(
          id: 6,
          name: 'Guía',
          clubTypeId: 1,
          investitureStatus: 'INVESTIDO',
          overallProgress: 100,
        ),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Guía'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Estado'), findsOneWidget);
    expect(find.text('Progreso'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Inscripción'), findsNothing);
    expect(find.text('Investidura'), findsNothing);
    expect(find.text('Año eclesiástico'), findsNothing);
  });

  testWidgets('tap incomplete circle opens not-completed copy', (tester) async {
    await pumpCircles(tester, classes: const []);
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Amigo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Amigo'), findsOneWidget);
    expect(
      find.text('Aún no has completado esta clase.'),
      findsOneWidget,
    );
    expect(find.text('Investido'), findsNothing);
  });
}

class _TestAssetLoader extends AssetLoader {
  final Map<String, dynamic> translations;

  const _TestAssetLoader(this.translations);

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return translations;
  }
}
