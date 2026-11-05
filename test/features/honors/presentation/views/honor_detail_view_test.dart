import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/providers/riverpod_aliases.dart';
import 'package:sacdia_app/core/utils/date_formatter.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/honors/data/models/user_honor_model.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor_category.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor_requirement.dart';
import 'package:sacdia_app/features/honors/domain/entities/requirement_evidence.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor_requirement_progress.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
import 'package:sacdia_app/features/honors/presentation/theme/honor_category_palette.dart';
import 'package:sacdia_app/features/honors/presentation/views/honor_detail_view.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_progress_band.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_segmented_tabs.dart';

import '../../../../support/l10n_test_support.dart';
import '../../../../support/riverpod_test_support.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._user);

  final UserEntity _user;

  @override
  Future<UserEntity?> build() async => _user;
}

class _RecordingEnrollNotifier extends HonorEnrollmentNotifier {
  final List<({String userId, int honorId})> calls = [];

  @override
  Future<void> enrollInHonor(String userId, int honorId) async {
    calls.add((userId: userId, honorId: honorId));
  }
}

class _RecordingCompletionModeNotifier
    extends HonorCompletionModeActionsNotifier {
  final List<HonorCompletionMode> modes = [];

  @override
  Future<UserHonor?> build() async => null;

  @override
  Future<bool> updateCompletionMode({
    required String userId,
    required int honorId,
    required HonorCompletionMode completionMode,
  }) async {
    modes.add(completionMode);
    state = AsyncValue.data(
      UserHonor(
        id: 77,
        honorId: honorId,
        userId: userId,
        completionMode: completionMode,
        validationStatus: 'IN_PROGRESS',
        date: DateTime(2026, 6, 11),
      ),
    );
    return true;
  }
}

class _PushRecorder extends NavigatorObserver {
  final List<Route<dynamic>> pushed = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }
}

HonorRequirement _req(
  int id, {
  bool choice = false,
  int? choiceMin,
  List<HonorRequirement> children = const [],
}) {
  return HonorRequirement(
    id: id,
    honorId: 7,
    requirementNumber: id,
    text: 'Texto $id',
    isChoiceGroup: choice,
    choiceMin: choiceMin,
    hasSubItems: children.isNotEmpty,
    children: children,
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

  // A leaf, a plain parent with three children and a choice group (1 of 2).
  final tree = [
    _req(1),
    _req(2, children: [_req(21), _req(22), _req(23)]),
    _req(3, choice: true, choiceMin: 1, children: [_req(31), _req(32)]),
  ];

  UserHonor userHonor({
    HonorCompletionMode mode = HonorCompletionMode.undecided,
    String status = 'IN_PROGRESS',
    DateTime? submittedAt,
    DateTime? validatedAt,
    String? validatedByName,
    String? validatedByRoleLabel,
    String? document,
    List<String> images = const [],
  }) {
    return UserHonor(
      id: 77,
      honorId: 7,
      userId: 'user-1',
      completionMode: mode,
      validationStatus: status,
      document: document,
      images: images,
      date: DateTime(2026, 6, 11),
      submittedAt: submittedAt,
      validatedAt: validatedAt,
      validatedByName: validatedByName,
      validatedByRoleLabel: validatedByRoleLabel,
    );
  }

  late _PushRecorder observer;

  Future<void> pumpDetail(
    WidgetTester tester, {
    List<UserHonor> userHonors = const [],
    Future<List<HonorRequirement>> Function()? requirements,
    List<UserHonorRequirementProgress> progress = const [],
    List<Override> extraOverrides = const [],
    bool disableAnimations = false,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    observer = _PushRecorder();

    await tester.pumpWidget(
      testProviderScope(
        overrides: [
          honorCategoriesProvider
              .overrideWith((ref) async => const <HonorCategory>[]),
          allHonorsProvider.overrideWith((ref) async => [honor]),
          activeHonorCatalogClubTypeIdProvider
              .overrideWith((ref) => const AsyncValue.data(null)),
          userHonorsProvider.overrideWith((ref) async => userHonors),
          userHonorProgressProvider(7).overrideWith((ref) async => progress),
          honorRequirementsProvider(7).overrideWith(
            (ref) => requirements?.call() ?? Future.value(tree),
          ),
          ...extraOverrides,
        ],
        child: MaterialApp(
          navigatorObservers: [observer],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: disableAnimations),
            child: child!,
          ),
          home: const HonorDetailView(honorId: 7, initialHonor: honor),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  HonorProgressBand bandOf(WidgetTester tester) =>
      tester.widget<HonorProgressBand>(find.byType(HonorProgressBand));

  List<String> tabsOf(WidgetTester tester) =>
      tester.widget<HonorSegmentedTabs>(find.byType(HonorSegmentedTabs)).labels;

  Future<void> openTab(WidgetTester tester, int index) async {
    await tester.tap(find.byKey(ValueKey('honor-tab-$index')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  SacButton buttonOf(WidgetTester tester, String key) =>
      tester.widget<SacButton>(find.byKey(ValueKey(key)));

  final bandColor = bandColorFor(
    categoryId: honor.categoryId,
    categoryName: honor.categoryName,
  );

  group('catalog (not enrolled)', () {
    testWidgets('band has no ring, no step and shows the levels',
        (tester) async {
      await pumpDetail(tester);

      final band = bandOf(tester);
      expect(band.bandColor, bandColor);
      expect(band.step, isNull);
      expect(band.progress, isNull);
      expect(band.honorName, 'Arte de acampar');
      expect(band.categoryName, 'Artes y Actividades Manuales');
      expect(band.metaLabel, 'Básico · General');
      expect(band.badge, isNull);
      expect(tabsOf(tester), ['Requisitos 3', 'Información']);
    });

    testWidgets('requirements tab lists the tree read-only with the caption',
        (tester) async {
      await pumpDetail(tester);

      expect(find.text('Texto 1'), findsOneWidget);
      expect(find.text('Texto 2'), findsOneWidget);
      expect(find.text('Texto 3'), findsOneWidget);
      // Only top-level rows: the children are summarized in a chip.
      expect(find.text('Texto 21'), findsNothing);
      expect(find.text('3 sub-requisitos'), findsOneWidget);
      expect(find.text('Elige 1 de 2'), findsOneWidget);
      expect(
        find.text(
            'Al inscribirte eliges si la trabajas dentro o fuera de la app.'),
        findsOneWidget,
      );
      // Read-only: no chevron rows, nothing tappable inside the list.
      expect(
          find.byKey(const ValueKey('requirement-preview-1')), findsOneWidget);
    });

    testWidgets('loading shows skeleton rows, not a stuck text',
        (tester) async {
      final completer = Completer<List<HonorRequirement>>();
      await pumpDetail(tester, requirements: () => completer.future);

      expect(find.byType(SacSkeletonList), findsOneWidget);
      expect(find.text('Cargando requisitos...'), findsNothing);
      expect(tabsOf(tester).first, 'Requisitos');

      completer.complete(tree);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SacSkeletonList), findsNothing);
      expect(find.text('Texto 1'), findsOneWidget);
    });

    testWidgets('a failure shows an inline error and retry loads the list',
        (tester) async {
      var calls = 0;
      await pumpDetail(
        tester,
        requirements: () {
          calls += 1;
          return calls == 1
              ? Future<List<HonorRequirement>>.error(Exception('boom'))
              : Future.value(tree);
        },
      );

      expect(find.text('Texto 1'), findsNothing);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);

      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(calls, 2);
      expect(find.text('Reintentar'), findsNothing);
      expect(find.text('Texto 1'), findsOneWidget);
    });

    testWidgets('information tab: description, material, levels, how it works',
        (tester) async {
      await pumpDetail(tester);
      await openTab(tester, 1);

      expect(find.text('Aprende a acampar con seguridad.'), findsOneWidget);
      expect(find.text('Material de estudio'), findsOneWidget);
      expect(find.text('Básico'), findsOneWidget);
      expect(find.text('General'), findsOneWidget);
      expect(find.text('Cómo funciona'), findsOneWidget);
      expect(find.text('Inscríbete'), findsOneWidget);
      expect(find.text('Elige el camino'), findsOneWidget);
      expect(find.text('Envía a revisión'), findsOneWidget);
    });

    testWidgets('"Inscribirme" is painted in the band color and enrolls',
        (tester) async {
      final enroll = _RecordingEnrollNotifier();
      await pumpDetail(
        tester,
        extraOverrides: [
          authNotifierProvider.overrideWith(
            () => _FakeAuthNotifier(
              const UserEntity(id: 'user-1', email: 'user@example.com'),
            ),
          ),
          honorEnrollmentNotifierProvider.overrideWith(() => enroll),
        ],
      );
      // The button reads the signed-in user without watching it: load it.
      final container =
          ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
      await tester.runAsync(() => container.read(authNotifierProvider.future));

      expect(find.text('Inscribirme'), findsOneWidget);
      expect(
          buttonOf(tester, 'honor-enroll-button').backgroundColor, bandColor);

      await tester.tap(find.byKey(const ValueKey('honor-enroll-button')));
      await tester.pump();

      expect(enroll.calls, [(userId: 'user-1', honorId: 7)]);
    });

    testWidgets('settles without frames when motion is reduced',
        (tester) async {
      await pumpDetail(tester, disableAnimations: true);
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('choose the work mode (undecided)', () {
    testWidgets('band reaches the first step, no ring, enrolled-on meta',
        (tester) async {
      await pumpDetail(tester, userHonors: [userHonor()]);

      final band = bandOf(tester);
      expect(band.step, HonorWorkStep.enrolled);
      expect(band.progress, isNull);
      expect(
        band.metaLabel,
        'Inscrita el ${SacDateFormatter.formatCalendar(DateTime(2026, 6, 11), 'd MMM yyyy')}'
        ' · elige cómo trabajarla',
      );
      expect(tabsOf(tester), ['Cómo trabajarla', 'Información']);
      expect(find.byKey(const ValueKey('honor-abandon-menu')), findsOneWidget);
    });

    testWidgets('shows the question, both options and a disabled CTA',
        (tester) async {
      await pumpDetail(tester, userHonors: [userHonor()]);

      expect(find.text('¿Cómo quieres completarla?'), findsOneWidget);
      expect(find.text('Completar dentro de la app'), findsOneWidget);
      expect(find.text('Completar fuera de la app'), findsOneWidget);
      expect(find.text('Elige cómo continuar'), findsOneWidget);
      expect(buttonOf(tester, 'honor-mode-continue-button').onPressed, isNull);
    });

    testWidgets('the CTA names the selected mode and confirms before saving',
        (tester) async {
      final recorder = _RecordingCompletionModeNotifier();
      await pumpDetail(
        tester,
        userHonors: [userHonor()],
        extraOverrides: [
          authNotifierProvider.overrideWith(
            () => _FakeAuthNotifier(
              const UserEntity(id: 'user-1', email: 'user@example.com'),
            ),
          ),
          honorCompletionModeActionsNotifierProvider
              .overrideWith(() => recorder),
        ],
      );

      await tester.tap(find.text('Completar dentro de la app'));
      await tester.pump();
      expect(find.text('Continuar dentro de la app'), findsOneWidget);
      expect(find.text('Elige cómo continuar'), findsNothing);

      await tester.tap(find.text('Completar fuera de la app'));
      await tester.pump();
      expect(find.text('Continuar fuera de la app'), findsOneWidget);

      await tester.tap(find.text('Continuar fuera de la app'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Confirmar modo de trabajo'), findsOneWidget);
      expect(recorder.modes, isEmpty);

      // Cancel keeps the screen as it was.
      await tester.tap(find.text('Cancelar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Confirmar modo de trabajo'), findsNothing);
      expect(recorder.modes, isEmpty);

      await tester.tap(find.text('Continuar fuera de la app'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Confirmar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(recorder.modes, [HonorCompletionMode.external]);
      // The choice leaves this screen (the dispatcher redirects to the
      // working screen).
      expect(find.text('¿Cómo quieres completarla?'), findsNothing);
    });

    testWidgets('information tab is the catalog one', (tester) async {
      await pumpDetail(tester, userHonors: [userHonor()]);
      await openTab(tester, 1);

      expect(find.text('Aprende a acampar con seguridad.'), findsOneWidget);
      expect(find.text('Cómo funciona'), findsOneWidget);
    });

    testWidgets('under review: locked notice, no choice and no CTA',
        (tester) async {
      await pumpDetail(
        tester,
        userHonors: [userHonor(status: 'PENDING_REVIEW')],
      );

      expect(find.text('¿Cómo quieres completarla?'), findsNothing);
      expect(find.text('Modo de trabajo bloqueado'), findsOneWidget);
      expect(find.byKey(const ValueKey('honor-mode-continue-button')),
          findsNothing);
      expect(bandOf(tester).step, HonorWorkStep.inReview);
      // Under review the honor can no longer be abandoned.
      expect(find.byKey(const ValueKey('honor-abandon-menu')), findsNothing);
    });
  });

  group('completed (validated)', () {
    final validatedAt = DateTime(2026, 6, 13, 16, 45);

    UserHonor approved({
      HonorCompletionMode mode = HonorCompletionMode.inApp,
      String? validatedByName,
      String? validatedByRoleLabel,
      List<String> images = const [],
      String? document,
    }) {
      return userHonor(
        mode: mode,
        status: 'APPROVED',
        submittedAt: DateTime(2026, 6, 12, 9, 30),
        validatedAt: validatedAt,
        validatedByName: validatedByName,
        validatedByRoleLabel: validatedByRoleLabel,
        images: images,
        document: document,
      );
    }

    testWidgets('band shows the finished path, full ring and the badge',
        (tester) async {
      await pumpDetail(tester, userHonors: [approved()]);

      final band = bandOf(tester);
      expect(band.step, HonorWorkStep.validated);
      expect(band.progress, 1);
      expect(
        band.metaLabel,
        'Validada el ${SacDateFormatter.dateShort(validatedAt)} · Dentro de la app',
      );
      final badge = band.badge! as SacBadge;
      expect(badge.label, 'Validada');
      expect(tabsOf(tester), ['Resumen', 'Mi trabajo']);
    });

    testWidgets('summary celebrates and lists the validation history',
        (tester) async {
      await pumpDetail(
        tester,
        userHonors: [
          approved(
              validatedByName: 'Directora Local',
              validatedByRoleLabel: 'Director')
        ],
      );

      expect(find.text('¡Especialidad lograda!'), findsOneWidget);
      expect(find.text('Ya aparece en tu perfil.'), findsOneWidget);
      expect(find.text('Inscrita el'), findsOneWidget);
      expect(find.text('Enviada a revisión'), findsOneWidget);
      expect(find.text('Validada el'), findsOneWidget);
      expect(find.text('Validada por'), findsOneWidget);
      expect(find.text('Directora Local'), findsOneWidget);
      expect(find.text('Director'), findsOneWidget);
    });

    testWidgets('"Validada por" says "No disponible" without a validator name',
        (tester) async {
      await pumpDetail(tester, userHonors: [approved()]);

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('history-validated-by')),
          matching: find.text('No disponible'),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'the payload of GET /users/:id/honors carries only validated_by_id, '
        'so the app has no validator name to show', (tester) async {
      // Shape the backend sends today (honors.service.ts getUserHonors): the
      // raw column, no `validated_by_name` / role keys.
      final model = UserHonorModel.fromJson({
        'user_honor_id': 77,
        'honor_id': 7,
        'user_id': 'user-1',
        'validation_status': 'APPROVED',
        'completion_mode': 'IN_APP',
        'date': '2026-06-11',
        'validated_at': '2026-06-13T16:45:00.000Z',
        'validated_by_id': '3f1c2f6e-0000-4000-8000-000000000001',
      });
      expect(model.validatedByName, isNull);

      await pumpDetail(tester, userHonors: [model.toEntity()]);

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('history-validated-by')),
          matching: find.text('No disponible'),
        ),
        findsOneWidget,
      );
      // The raw id is never shown.
      expect(find.textContaining('3f1c2f6e'), findsNothing);
    });

    testWidgets('"Mi trabajo" shows the in-app answers and evidences',
        (tester) async {
      await pumpDetail(
        tester,
        userHonors: [approved()],
        progress: [
          UserHonorRequirementProgress(
            requirementId: 101,
            requirementNumber: 1,
            text: 'Explica lo aprendido',
            completed: true,
            completedAt: DateTime(2026, 6, 12, 10),
            textResponse: 'Aprendí a documentar mi trabajo.',
            evidences: const [
              RequirementEvidence(
                id: 1,
                evidenceType: EvidenceType.file,
                url: 'https://example.com/evidence.pdf',
                filename: 'evidence.pdf',
              ),
            ],
          ),
        ],
      );
      await openTab(tester, 1);

      expect(find.text('Trabajo realizado en la app'), findsOneWidget);
      expect(find.text('Aprendí a documentar mi trabajo.'), findsOneWidget);
      expect(find.text('evidence.pdf'), findsOneWidget);
      expect(find.text('Trabajo externo y evidencias'), findsNothing);
    });

    testWidgets('"Mi trabajo" of an external honor shows the files',
        (tester) async {
      await pumpDetail(
        tester,
        userHonors: [
          approved(
            mode: HonorCompletionMode.external,
            document: 'https://example.com/completed.pdf',
            images: const ['https://example.com/evidence.pdf'],
          ),
        ],
      );
      await openTab(tester, 1);

      expect(find.text('Trabajo externo y evidencias'), findsOneWidget);
      expect(find.text('Formato completado'), findsOneWidget);
      expect(find.text('Trabajo realizado en la app'), findsNothing);
      expect(bandOf(tester).metaLabel, endsWith('Fuera de la app'));
    });

    testWidgets('a legacy approved honor without mode reads as external',
        (tester) async {
      await pumpDetail(
        tester,
        userHonors: [
          approved(
            mode: HonorCompletionMode.undecided,
            images: const ['https://example.com/evidence.jpg'],
          ),
        ],
      );

      expect(bandOf(tester).metaLabel, endsWith('Fuera de la app (histórico)'));
      await openTab(tester, 1);
      expect(find.text('Trabajo realizado en la app'), findsNothing);
      expect(find.text('Trabajo externo y evidencias'), findsOneWidget);
    });

    testWidgets('the sticky CTA opens the profile, where honors are listed',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) =>
                const HonorDetailView(honorId: 7, initialHonor: honor),
          ),
          GoRoute(
            path: RouteNames.homeProfile,
            builder: (_, __) => const Text('profile-page'),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        testProviderScope(
          overrides: [
            honorCategoriesProvider
                .overrideWith((ref) async => const <HonorCategory>[]),
            allHonorsProvider.overrideWith((ref) async => [honor]),
            activeHonorCatalogClubTypeIdProvider
                .overrideWith((ref) => const AsyncValue.data(null)),
            userHonorsProvider.overrideWith((ref) async => [approved()]),
            userHonorProgressProvider(7).overrideWith((ref) async => const []),
            honorRequirementsProvider(7)
                .overrideWith((ref) => Future.value(tree)),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Ya aparece en tu perfil.'), findsOneWidget);
      expect(find.text('Ver en mi perfil'), findsOneWidget);
      expect(
          buttonOf(tester, 'honor-profile-button').backgroundColor, bandColor);

      await tester.tap(find.byKey(const ValueKey('honor-profile-button')));
      await tester.pumpAndSettle();

      expect(find.text('profile-page'), findsOneWidget);
    });
  });
}
