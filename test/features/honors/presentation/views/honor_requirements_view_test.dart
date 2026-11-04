import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor_category.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor_requirement.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor_requirement_progress.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
import 'package:sacdia_app/features/honors/presentation/theme/honor_category_palette.dart';
import 'package:sacdia_app/features/honors/presentation/views/honor_requirements_view.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_progress_band.dart';
import 'package:sacdia_app/features/validation/domain/entities/validation.dart';
import 'package:sacdia_app/features/validation/presentation/providers/validation_providers.dart';

import '../../../../support/l10n_test_support.dart';
import '../../../../support/riverpod_test_support.dart';

class _RecordingProgressNotifier extends RequirementProgressNotifier {
  _RecordingProgressNotifier(super.arg, this.calls);

  final List<List<Map<String, dynamic>>> calls;

  @override
  Future<bool> bulkUpdate(List<Map<String, dynamic>> updates) async {
    calls.add(updates);
    return true;
  }
}

class _RecordingSubmitNotifier extends SubmitValidationNotifier {
  final List<({ValidationEntityType type, int id})> calls = [];

  @override
  Future<bool> submit({
    required ValidationEntityType entityType,
    required int entityId,
  }) async {
    calls.add((type: entityType, id: entityId));
    return true;
  }
}

HonorRequirement _req(
  int id, {
  int? parentId,
  bool choice = false,
  int? choiceMin,
  bool evidence = false,
  List<HonorRequirement> children = const [],
}) {
  return HonorRequirement(
    id: id,
    honorId: 7,
    requirementNumber: id,
    text: 'Texto $id',
    parentId: parentId,
    isChoiceGroup: choice,
    choiceMin: choiceMin,
    requiresEvidence: evidence,
    hasSubItems: children.isNotEmpty,
    children: children,
  );
}

UserHonorRequirementProgress _done(int id, {String response = 'listo'}) {
  return UserHonorRequirementProgress(
    requirementId: id,
    requirementNumber: id,
    text: 'Texto $id',
    completed: true,
    textResponse: response,
  );
}

void main() {
  setUpAll(loadSpanishTranslations);

  const honor = Honor(
    id: 7,
    name: 'Arte de acampar',
    description: 'Aprende a acampar con seguridad.',
    categoryId: 1,
    categoryName: 'Artes y Actividades Manuales',
    approval: 1,
    skillLevel: 1,
    clubTypeId: 1,
    materialUrl: 'https://example.com/form.pdf',
  );

  UserHonor userHonor({
    String status = 'IN_PROGRESS',
    HonorCompletionMode mode = HonorCompletionMode.inApp,
    DateTime? completedAt,
    String? rejectionReason,
  }) {
    return UserHonor(
      id: 77,
      honorId: 7,
      userId: 'user-1',
      completionMode: mode,
      validationStatus: status,
      date: DateTime(2026, 6, 11),
      completedAt: completedAt,
      rejectionReason: rejectionReason,
    );
  }

  // Three top-level requirements: a leaf, a plain parent with three children
  // and a choice group (choose 1 of 2).
  final tree = [
    _req(1),
    _req(2, children: [
      _req(21, parentId: 2),
      _req(22, parentId: 2),
      _req(23, parentId: 2),
    ]),
    _req(3, choice: true, choiceMin: 1, children: [
      _req(31, parentId: 3),
      _req(32, parentId: 3),
    ]),
  ];

  late _RecordingSubmitNotifier submitNotifier;
  late List<List<Map<String, dynamic>>> bulkCalls;
  late UserHonor currentUserHonor;

  Future<void> pumpView(
    WidgetTester tester, {
    UserHonor? userHonorValue,
    List<HonorRequirement>? requirements,
    List<UserHonorRequirementProgress> progress = const [],
    Future<List<HonorRequirement>> Function()? requirementsLoader,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    currentUserHonor = userHonorValue ?? userHonor();
    submitNotifier = _RecordingSubmitNotifier();
    bulkCalls = [];

    await tester.pumpWidget(
      testProviderScope(
        overrides: [
          honorCategoriesProvider
              .overrideWith((ref) async => const <HonorCategory>[]),
          allHonorsProvider.overrideWith((ref) async => [honor]),
          activeHonorCatalogClubTypeIdProvider
              .overrideWith((ref) => const AsyncValue.data(null)),
          userHonorsProvider.overrideWith((ref) async => [currentUserHonor]),
          honorRequirementsProvider(7).overrideWith(
            (ref) =>
                requirementsLoader?.call() ??
                Future.value(requirements ?? tree),
          ),
          userHonorProgressProvider(7).overrideWith((ref) async => progress),
          requirementProgressNotifierProvider(7)
              .overrideWith(() => _RecordingProgressNotifier(7, bulkCalls)),
          submitValidationProvider.overrideWith(() => submitNotifier),
        ],
        child: const MaterialApp(
          home: HonorRequirementsView(
            honorId: 7,
            userHonorId: 77,
            honorName: 'Arte de acampar',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  BoxDecoration circleOf(WidgetTester tester, int id) {
    final box = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(ValueKey('requirement-status-$id')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    return box.decoration! as BoxDecoration;
  }

  SacButton submitButton(WidgetTester tester) => tester
      .widget<SacButton>(find.byKey(const ValueKey('honor-submit-button')));

  group('band and path', () {
    testWidgets('paints the darkened category color and shows the honor',
        (tester) async {
      await pumpView(tester);

      final band = tester.widget<HonorProgressBand>(
        find.byType(HonorProgressBand),
      );
      expect(
        band.bandColor,
        bandColorFor(categoryName: 'Artes y Actividades Manuales'),
      );
      expect(
        contrastOnWhite(band.bandColor),
        greaterThanOrEqualTo(kBandMinContrastOnWhite),
      );
      expect(find.text('Arte de acampar'), findsOneWidget);
      expect(find.text('Artes y Actividades Manuales'), findsOneWidget);
      expect(find.text('0% · Dentro de la app'), findsOneWidget);
    });

    for (final entry in {
      'IN_PROGRESS': (HonorWorkStep.working, 'Etapa 2 de 4: Trabajando'),
      'REJECTED': (HonorWorkStep.working, 'Etapa 2 de 4: Trabajando'),
      'PENDING_REVIEW': (HonorWorkStep.inReview, 'Etapa 3 de 4: En revisión'),
    }.entries) {
      testWidgets('${entry.key} sits on step ${entry.value.$1.name}',
          (tester) async {
        final handle = tester.ensureSemantics();
        await pumpView(
          tester,
          userHonorValue: userHonor(status: entry.key),
        );

        expect(
          tester.widget<HonorStepPath>(find.byType(HonorStepPath)).step,
          entry.value.$1,
        );
        expect(find.bySemanticsLabel(entry.value.$2), findsOneWidget);
        handle.dispose();
      });
    }

    test('APPROVED maps to the last step', () {
      expect(
        honorWorkStepFor(userHonor(status: 'APPROVED')),
        HonorWorkStep.validated,
      );
    });
  });

  group('tabs and rows', () {
    testWidgets('switches between Requisitos and Información', (tester) async {
      await pumpView(tester);

      expect(find.text('Requisitos 0/3'), findsOneWidget);
      expect(find.text('Información'), findsOneWidget);
      expect(find.byKey(const ValueKey('requirement-row-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('info-row-date')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('honor-tab-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const ValueKey('requirement-row-1')), findsNothing);
      expect(find.byKey(const ValueKey('info-row-date')), findsOneWidget);
      expect(find.text('Aprende a acampar con seguridad.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('honor-tab-0')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('requirement-row-1')), findsOneWidget);
    });

    testWidgets('row statuses and chips come from the readiness rules',
        (tester) async {
      await pumpView(
        tester,
        progress: [_done(1), _done(21)],
      );

      final paint = getCategoryPaintColor(
        categoryName: 'Artes y Actividades Manuales',
      );
      // Requisito 1: done (filled). Requisito 2: partial (tint + border).
      // Requisito 3: todo (no fill).
      expect(circleOf(tester, 1).color, paint);
      expect(circleOf(tester, 2).color, paint.withValues(alpha: 0.12));
      expect((circleOf(tester, 2).border! as Border).top.color, paint);
      expect(circleOf(tester, 3).color, Colors.transparent);

      expect(find.text('Requisitos 1/3'), findsOneWidget);
      expect(find.text('Respondido'), findsOneWidget);
      expect(find.text('1 de 3 hechos'), findsOneWidget);
      expect(find.text('Elige 1 · 0 hechos'), findsOneWidget);
      // 1 done + partial 1/3 + 0, averaged over three requirements.
      expect(find.text('44% · Dentro de la app'), findsOneWidget);
    });

    testWidgets('a requirement that needs evidence shows "Falta foto"',
        (tester) async {
      await pumpView(
        tester,
        requirements: [_req(1, evidence: true)],
        progress: [_done(1)],
      );

      expect(find.text('Falta foto'), findsOneWidget);
      expect(find.text('Requisitos 0/1'), findsOneWidget);
    });

    testWidgets('there is no global save bar', (tester) async {
      await pumpView(tester);

      expect(find.text('Guardar cambios'), findsNothing);
      expect(find.byType(SacButton), findsOneWidget);
      expect(find.text('Enviar a revisión'), findsOneWidget);
    });
  });

  group('requirement sheet', () {
    testWidgets('saves only the nodes that changed in its subtree',
        (tester) async {
      await pumpView(tester, progress: [_done(1), _done(21)]);

      await tester.tap(find.byKey(const ValueKey('requirement-row-2')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Requisito 2'), findsOneWidget);
      // One response field per child; the plain parent has none.
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(3));

      await tester.enterText(fields.at(1), 'mi respuesta');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('requirement-check')).at(1));
      await tester.pump();

      await tester.tap(find.text('Guardar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(bulkCalls, hasLength(1));
      expect(bulkCalls.single, [
        {
          'requirementId': 22,
          'completed': true,
          'notes': '',
          'textResponse': 'mi respuesta',
        },
      ]);
      // The sheet is gone.
      expect(find.text('Requisito 2'), findsNothing);
    });

    testWidgets('closing with unsaved edits asks first', (tester) async {
      await pumpView(tester);

      await tester.tap(find.byKey(const ValueKey('requirement-row-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.enterText(find.byType(TextField), 'borrador');
      await tester.pump();

      await tester.tap(find.byTooltip('Close'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Cambios sin guardar'), findsOneWidget);

      await tester.tap(find.text('Quedarme'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Requisito 1'), findsOneWidget);
      expect(bulkCalls, isEmpty);

      await tester.tap(find.byTooltip('Close'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Salir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Requisito 1'), findsNothing);
      expect(bulkCalls, isEmpty);
    });

    testWidgets('saving without changes just closes', (tester) async {
      await pumpView(tester);

      await tester.tap(find.byKey(const ValueKey('requirement-row-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Guardar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(bulkCalls, isEmpty);
      expect(find.text('Requisito 1'), findsNothing);
    });

    testWidgets('a choice group sheet shows how many to complete',
        (tester) async {
      await pumpView(tester, progress: [_done(31)]);

      await tester.tap(find.byKey(const ValueKey('requirement-row-3')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Completa 1 de 2'), findsOneWidget);
    });
  });

  group('submit bar', () {
    testWidgets('is disabled and says what is missing', (tester) async {
      await pumpView(tester, progress: [_done(1)]);

      expect(
        find.text('Te falta: 2 requisitos y la fecha de finalización'),
        findsOneWidget,
      );
      expect(submitButton(tester).onPressed, isNull);
    });

    testWidgets('names missing evidence on its own', (tester) async {
      await pumpView(
        tester,
        userHonorValue: userHonor(completedAt: DateTime(2026, 6, 20)),
        requirements: [_req(1, evidence: true)],
        progress: [_done(1)],
      );

      expect(find.text('Te falta: 1 evidencia'), findsOneWidget);
      expect(submitButton(tester).onPressed, isNull);
    });

    testWidgets('missing date only', (tester) async {
      await pumpView(
        tester,
        requirements: [_req(1)],
        progress: [_done(1)],
      );

      expect(find.text('Te falta: la fecha de finalización'), findsOneWidget);
      expect(submitButton(tester).onPressed, isNull);
    });

    testWidgets('enables when ready and submits the user honor id',
        (tester) async {
      await pumpView(
        tester,
        userHonorValue: userHonor(completedAt: DateTime(2026, 6, 20)),
        requirements: [_req(1), _req(2)],
        progress: [_done(1), _done(2)],
      );

      expect(find.text('Todo listo para enviar'), findsOneWidget);
      expect(find.text('Requisitos 2/2'), findsOneWidget);
      expect(find.text('100% · Dentro de la app'), findsOneWidget);
      expect(submitButton(tester).onPressed, isNotNull);

      // The list reloads with the new status after the submit.
      currentUserHonor = userHonor(
        status: 'PENDING_REVIEW',
        completedAt: DateTime(2026, 6, 20),
      );
      await tester.tap(find.byKey(const ValueKey('honor-submit-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(submitNotifier.calls, hasLength(1));
      expect(submitNotifier.calls.single.type, ValidationEntityType.honor);
      expect(submitNotifier.calls.single.id, 77);
      expect(find.text('Enviada a revisión'), findsOneWidget);
      // The band moved to "En revisión" and the button is gone.
      expect(
        tester.widget<HonorStepPath>(find.byType(HonorStepPath)).step,
        HonorWorkStep.inReview,
      );
      expect(find.byKey(const ValueKey('honor-submit-button')), findsNothing);
    });

    testWidgets('under review: badge and hint, no button, read-only sheet',
        (tester) async {
      await pumpView(
        tester,
        userHonorValue: userHonor(
          status: 'PENDING_REVIEW',
          completedAt: DateTime(2026, 6, 20),
        ),
        progress: [_done(1)],
      );

      expect(
        find.text('Un responsable está revisando tu trabajo'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('honor-submit-button')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('requirement-row-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Requisito 1'), findsOneWidget);
      expect(find.text('Guardar'), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    });
  });

  group('rejected honor', () {
    testWidgets('shows the reason on both tabs and can be resent',
        (tester) async {
      await pumpView(
        tester,
        userHonorValue: userHonor(
          status: 'REJECTED',
          rejectionReason: 'Falta la foto del punto 2',
        ),
      );

      expect(find.text('Tu especialidad fue rechazada'), findsOneWidget);
      expect(find.text('Falta la foto del punto 2'), findsOneWidget);
      expect(find.text('Corrige y vuelve a enviar'), findsOneWidget);
      expect(find.byKey(const ValueKey('honor-submit-button')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('honor-tab-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Tu especialidad fue rechazada'), findsOneWidget);
      expect(find.text('Falta la foto del punto 2'), findsOneWidget);
    });

    testWidgets('falls back to the "no reason" copy', (tester) async {
      await pumpView(tester, userHonorValue: userHonor(status: 'REJECTED'));
      expect(find.text('Sin motivo especificado'), findsOneWidget);
    });

    testWidgets('an in-progress honor shows no rejection card', (tester) async {
      await pumpView(tester);
      expect(find.byKey(const ValueKey('honor-rejection-card')), findsNothing);
    });
  });

  group('info tab', () {
    testWidgets('asks for the date when unset and shows it when set',
        (tester) async {
      await pumpView(tester);
      await tester.tap(find.byKey(const ValueKey('honor-tab-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Fecha de finalización'), findsOneWidget);
      expect(find.text('Necesaria para enviar a revisión'), findsOneWidget);
      expect(find.text('Material de estudio'), findsOneWidget);
      expect(find.text('Dentro de la app'), findsWidgets);
      expect(find.text('Básico'), findsOneWidget);
      expect(find.text('General'), findsOneWidget);
      expect(find.textContaining('Inscrita el'), findsOneWidget);
    });

    testWidgets('shows the saved date', (tester) async {
      await pumpView(
        tester,
        userHonorValue: userHonor(completedAt: DateTime(2026, 6, 20)),
      );
      await tester.tap(find.byKey(const ValueKey('honor-tab-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Necesaria para enviar a revisión'), findsNothing);
      expect(find.textContaining('2026'), findsWidgets);
    });
  });

  group('states', () {
    testWidgets('loading shows a skeleton', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testProviderScope(
          overrides: [
            honorCategoriesProvider
                .overrideWith((ref) async => const <HonorCategory>[]),
            allHonorsProvider.overrideWith((ref) async => [honor]),
            activeHonorCatalogClubTypeIdProvider
                .overrideWith((ref) => const AsyncValue.data(null)),
            userHonorsProvider.overrideWith((ref) async => [userHonor()]),
            honorRequirementsProvider(7).overrideWith(
              (ref) => Future<List<HonorRequirement>>.delayed(
                const Duration(days: 1),
                () => const <HonorRequirement>[],
              ),
            ),
            userHonorProgressProvider(7).overrideWith(
              (ref) async => const <UserHonorRequirementProgress>[],
            ),
          ],
          child: const MaterialApp(
            home: HonorRequirementsView(
              honorId: 7,
              userHonorId: 77,
              honorName: 'Arte de acampar',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SacSkeletonList), findsOneWidget);
      expect(find.byType(HonorProgressBand), findsNothing);
      // Dispose the pending timer.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(days: 2));
    });

    testWidgets('a failed load shows the error state with retry',
        (tester) async {
      await pumpView(
        tester,
        requirementsLoader: () async => throw Exception('boom'),
      );

      expect(find.byType(SacErrorState), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.textContaining('boom'), findsNothing);
    });

    testWidgets('external honors keep the mode guard', (tester) async {
      await pumpView(
        tester,
        userHonorValue: userHonor(mode: HonorCompletionMode.external),
      );

      expect(find.text('Este no es el camino activo'), findsOneWidget);
      expect(find.byType(HonorProgressBand), findsNothing);
    });
  });
}
