import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_judge_assignment.dart';
import 'package:sacdia_app/features/camporees/presentation/providers/camporees_providers.dart';
import 'package:sacdia_app/features/camporees/presentation/views/judge_assignments_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('agrupa clubes bajo el mismo evento y quita el CTA coral',
      (tester) async {
    await _pumpAssignments(
      tester,
      const [
        CamporeeJudgeAssignment(
          assignmentId: 'a-1',
          eventId: 10,
          judgeId: 'judge-1',
          clubSectionId: 2,
          judgeRole: 'primary',
          active: true,
          eventTitle: 'Orden cerrado QA',
          clubName: 'Estella',
          sectionName: 'Conquistadores',
          canSubmitScore: true,
        ),
        CamporeeJudgeAssignment(
          assignmentId: 'a-2',
          eventId: 10,
          judgeId: 'judge-1',
          clubSectionId: 3,
          judgeRole: 'primary',
          active: true,
          eventTitle: 'Orden cerrado QA',
          clubName: 'ACV',
          canSubmitScore: true,
        ),
        CamporeeJudgeAssignment(
          assignmentId: 'a-3',
          eventId: 11,
          judgeId: 'judge-1',
          clubSectionId: 3,
          judgeRole: 'primary',
          active: true,
          eventTitle: 'Uniformidad QA app',
          clubName: 'ACV',
          canSubmitScore: true,
        ),
        CamporeeJudgeAssignment(
          assignmentId: 'assistant',
          eventId: 10,
          judgeId: 'judge-1',
          clubSectionId: 9,
          judgeRole: 'assistant',
          active: true,
          eventTitle: 'Orden cerrado QA',
          clubName: 'No debe verse',
          canSubmitScore: false,
        ),
      ],
    );

    expect(find.text('Orden cerrado QA'), findsOneWidget);
    expect(find.text('Uniformidad QA app'), findsOneWidget);
    expect(find.text('Estella'), findsOneWidget);
    expect(find.text('Conquistadores'), findsOneWidget);
    expect(find.text('ACV'), findsNWidgets(2));
    expect(find.text('3 clubes'), findsOneWidget);
    expect(find.text('2 eventos'), findsOneWidget);
    expect(find.text('2 clubes'), findsOneWidget);
    expect(find.text('1 club'), findsOneWidget);
    expect(find.text('Cargar puntaje'), findsNothing);
    expect(find.text('Cargar'), findsNWidgets(3));
    expect(find.byType(SacButton), findsNothing);
    expect(find.text('No debe verse'), findsNothing);
    expect(find.byType(SacPressable), findsNWidgets(3));
  });

  testWidgets('vacío muestra hint de juez principal', (tester) async {
    await _pumpAssignments(tester, const []);

    expect(
      find.text('No tienes evaluaciones como juez principal.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(SacButton, 'Reintentar'), findsOneWidget);
  });

  testWidgets('filas del mismo club muestran sección para distinguirlas',
      (tester) async {
    await _pumpAssignments(
      tester,
      const [
        CamporeeJudgeAssignment(
          assignmentId: 'a-1',
          eventId: 10,
          judgeId: 'judge-1',
          clubSectionId: 2,
          judgeRole: 'primary',
          active: true,
          eventTitle: 'Orden cerrado QA',
          clubName: 'Estella',
          canSubmitScore: true,
        ),
        CamporeeJudgeAssignment(
          assignmentId: 'a-2',
          eventId: 10,
          judgeId: 'judge-1',
          clubSectionId: 7,
          judgeRole: 'primary',
          active: true,
          eventTitle: 'Orden cerrado QA',
          clubName: 'Estella',
          canSubmitScore: true,
        ),
      ],
    );

    expect(find.text('Estella'), findsNWidgets(2));
    expect(find.text('Sección #2'), findsOneWidget);
    expect(find.text('Sección #7'), findsOneWidget);
  });
}

Future<void> _pumpAssignments(
  WidgetTester tester,
  List<CamporeeJudgeAssignment> assignments,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        camporeeJudgeAssignmentsProvider.overrideWith(
          (ref) async => assignments,
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
            home: const JudgeAssignmentsView(),
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
