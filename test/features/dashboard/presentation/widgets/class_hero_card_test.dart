import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_progress_bar.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/features/classes/domain/entities/class_module_detail.dart';
import 'package:sacdia_app/features/classes/domain/entities/class_requirement.dart';
import 'package:sacdia_app/features/classes/domain/entities/class_with_progress.dart';
import 'package:sacdia_app/features/classes/domain/entities/requirement_track.dart';
import 'package:sacdia_app/features/classes/presentation/providers/classes_providers.dart';
import 'package:sacdia_app/features/dashboard/presentation/widgets/class_hero_card.dart';
import '../../../../support/l10n_test_support.dart';
import '../../../../support/riverpod_test_support.dart';

ClassRequirement _req(
  int id,
  String name,
  RequirementStatus status, {
  RequirementTrack? track,
  bool? required = true,
  int? order,
}) {
  return ClassRequirement(
    id: id,
    name: name,
    moduleId: 1,
    status: status,
    requirementTrack: track,
    requiredForInvestiture: required,
    displayOrder: order,
  );
}

ClassWithProgress _class(
  List<List<ClassRequirement>> modules, {
  String? investitureStatus,
}) {
  return ClassWithProgress(
    id: 7,
    name: 'Amigo',
    clubTypeId: 2,
    investitureStatus: investitureStatus,
    modules: [
      for (var i = 0; i < modules.length; i++)
        ClassModuleDetail(
          id: i + 1,
          name: 'Module ${i + 1}',
          classId: 7,
          requirements: modules[i],
        ),
    ],
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required Future<ClassWithProgress> Function() loader,
  double fallbackProgress = 0.5,
  bool initialIsExpired = false,
  int? classId = 7,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(
          body: SingleChildScrollView(
            child: ClassHeroCard(
              currentClassName: 'Amigo',
              currentClassId: classId,
              fallbackProgress: fallbackProgress,
              initialIsExpired: initialIsExpired,
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/class/:id',
        builder: (_, state) =>
            Scaffold(body: Text('class detail ${state.pathParameters['id']}')),
      ),
    ],
  );
  await tester.pumpWidget(
    testProviderScope(
      overrides: [
        classWithProgressProvider.overrideWith((ref, query) => loader()),
        userClassesProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(loadSpanishTranslations);

  group('nextClassRequirement', () {
    test('picks the first unresolved required requirement by module then order',
        () {
      final cwp = _class([
        [
          _req(1, 'done', RequirementStatus.validado, order: 1),
          _req(2, 'sent', RequirementStatus.enviado, order: 2),
        ],
        [
          _req(3, 'later', RequirementStatus.pendiente, order: 5),
          _req(4, 'earlier', RequirementStatus.rechazado, order: 2),
          _req(5, 'unordered', RequirementStatus.observado),
        ],
      ]);

      expect(nextClassRequirement(cwp)?.name, 'earlier');
    });

    test('skips advanced track, non-required and already-resolved ones', () {
      final cwp = _class([
        [
          _req(1, 'advanced', RequirementStatus.pendiente,
              track: RequirementTrack.advanced),
          _req(2, 'optional', RequirementStatus.pendiente, required: false),
          _req(3, 'sent', RequirementStatus.enviado),
          _req(4, 'legacy null flag', RequirementStatus.pendiente,
              required: null),
        ],
      ]);

      expect(nextClassRequirement(cwp)?.name, 'legacy null flag');
    });

    test('is null when everything is resolved', () {
      final cwp = _class([
        [_req(1, 'done', RequirementStatus.validado)],
      ]);

      expect(nextClassRequirement(cwp), isNull);
    });
  });

  group('ClassHeroCard', () {
    testWidgets('counts and percent come from the loaded class',
        (tester) async {
      final cwp = _class([
        [
          _req(1, 'a', RequirementStatus.validado, order: 1),
          _req(2, 'b', RequirementStatus.validado, order: 2),
          _req(3, 'Primeros auxilios', RequirementStatus.pendiente, order: 3),
        ],
      ]);
      // fallback says 90 % but the loaded class says 2/3 -> 66 %.
      await _pump(
        tester,
        loader: () async => cwp,
        fallbackProgress: 0.9,
      );

      expect(find.text('Mi clase'), findsOneWidget);
      expect(find.text('Amigo'), findsOneWidget);
      expect(find.text('2 de 3 requisitos'), findsOneWidget);
      expect(find.text('66%'), findsOneWidget);
      expect(find.text('90%'), findsNothing);
      expect(
        tester.widget<SacProgressBar>(find.byType(SacProgressBar)).progress,
        closeTo(2 / 3, 1e-9),
      );
      expect(
        find.textContaining('Primeros auxilios', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('Siguiente:', findRichText: true),
          findsOneWidget);
      expect(find.text('Continuar mi clase'), findsOneWidget);
    });

    testWidgets('singular requirement count', (tester) async {
      await _pump(
        tester,
        loader: () async => _class([
          [_req(1, 'only', RequirementStatus.pendiente)],
        ]),
      );

      expect(find.text('0 de 1 requisito'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets('loading shows the summary percent and a skeleton for counts',
        (tester) async {
      final completer = Completer<ClassWithProgress>();
      await _pump(
        tester,
        loader: () => completer.future,
        fallbackProgress: 0.4,
      );

      expect(find.text('40%'), findsOneWidget);
      expect(find.byType(SacSkeletonBox), findsOneWidget);
      expect(find.textContaining('requisito'), findsNothing);
      expect(
          find.textContaining('Siguiente:', findRichText: true), findsNothing);
      // The button is already usable: it only needs the class id.
      expect(find.text('Continuar mi clase'), findsOneWidget);

      completer.complete(
        _class([
          [
            _req(1, 'a', RequirementStatus.validado),
            _req(2, 'b', RequirementStatus.pendiente),
          ],
        ]),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('1 de 2 requisitos'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.byType(SacSkeletonBox), findsNothing);
    });

    testWidgets('error falls back to the percent only', (tester) async {
      await _pump(
        tester,
        loader: () async => throw Exception('boom'),
        fallbackProgress: 0.25,
      );

      expect(find.text('25%'), findsOneWidget);
      expect(find.byType(SacSkeletonBox), findsNothing);
      expect(find.textContaining('requisito'), findsNothing);
      expect(
          find.textContaining('Siguiente:', findRichText: true), findsNothing);
      expect(find.text('Continuar mi clase'), findsOneWidget);
    });

    testWidgets('completed class shows the badge and "Ver mi clase"',
        (tester) async {
      await _pump(
        tester,
        loader: () async => _class([
          [
            _req(1, 'a', RequirementStatus.validado),
            _req(2, 'b', RequirementStatus.validado),
          ],
        ]),
      );

      expect(find.byType(SacBadge), findsOneWidget);
      expect(find.text('Completada'), findsOneWidget);
      expect(find.text('100%'), findsNothing);
      expect(find.text('2 de 2 requisitos'), findsOneWidget);
      expect(find.text('Ver mi clase'), findsOneWidget);
      expect(find.text('Continuar mi clase'), findsNothing);
      expect(
          find.textContaining('Siguiente:', findRichText: true), findsNothing);
    });

    testWidgets('expired class shows the badge, label and "Ver mi clase"',
        (tester) async {
      await _pump(
        tester,
        initialIsExpired: true,
        loader: () async => _class([
          [_req(1, 'a', RequirementStatus.pendiente)],
        ]),
      );

      expect(find.text('Vencida'), findsOneWidget);
      expect(find.text('Clase vencida'), findsOneWidget);
      expect(find.text('Mi clase'), findsNothing);
      expect(find.text('Ver mi clase'), findsOneWidget);
      expect(
          find.textContaining('Siguiente:', findRichText: true), findsNothing);
    });

    testWidgets('expired flag from the loaded class is honoured too',
        (tester) async {
      await _pump(
        tester,
        loader: () async => _class(
          [
            [_req(1, 'a', RequirementStatus.pendiente)],
          ],
          investitureStatus: 'EXPIRED',
        ),
      );

      expect(find.text('Vencida'), findsOneWidget);
      expect(find.text('Ver mi clase'), findsOneWidget);
    });

    testWidgets('the button opens the class detail', (tester) async {
      await _pump(
        tester,
        loader: () async => _class([
          [_req(1, 'a', RequirementStatus.pendiente)],
        ]),
      );

      await tester.tap(find.byType(SacButton));
      await tester.pumpAndSettle();

      expect(find.text('class detail 7'), findsOneWidget);
    });

    testWidgets('without a class id there is no button', (tester) async {
      await _pump(
        tester,
        classId: null,
        loader: () async => throw StateError('must not be called'),
        fallbackProgress: 0.4,
      );

      expect(find.text('40%'), findsOneWidget);
      expect(find.byType(SacButton), findsNothing);
    });
  });
}
