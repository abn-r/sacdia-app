import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/widgets/status_progress/status_progress.dart';
import 'package:sacdia_app/features/classes/domain/entities/progressive_class.dart';
import 'package:sacdia_app/features/classes/presentation/providers/classes_providers.dart';
import 'package:sacdia_app/features/investiture_requests/domain/entities/own_investiture_entry.dart';
import 'package:sacdia_app/features/investiture_requests/domain/entities/person_status.dart';
import 'package:sacdia_app/features/investiture_requests/presentation/providers/investiture_requests_providers.dart';
import 'package:sacdia_app/features/investiture_requests/presentation/utils/own_investiture_selection.dart';
import 'package:sacdia_app/features/investiture_requests/presentation/views/own_investiture_view.dart';
import 'package:sacdia_app/providers/catalogs_provider.dart';

import '../fake_investiture_requests_repository.dart';
import 'investiture_test_harness.dart';

OwnInvestitureEntry _entry(
  String id,
  PersonStatus status, {
  String className = 'Amigo',
  int classId = 3,
  int yearId = 9,
  DateTime? date,
  String? systemReason,
  String? rejectionReason,
  String? comment,
  String? resolvedBy,
  DateTime? resolvedAt,
}) =>
    OwnInvestitureEntry(
      personId: id,
      userId: 'u1',
      classId: classId,
      className: className,
      clubSectionId: 4,
      ecclesiasticalYearId: yearId,
      investitureDate: date ?? DateTime(2026, 11, 15),
      status: status,
      systemReason: systemReason,
      rejectionReason: rejectionReason,
      authorizationComment: comment,
      resolvedByName: resolvedBy,
      resolvedAt: resolvedAt,
    );

Future<void> _pump(
  WidgetTester tester,
  FakeInvestitureRequestsRepository repo, {
  List<ProgressiveClass> classes = const [],
}) =>
    pumpApp(
      tester,
      const OwnInvestitureView(),
      overrides: [
        investitureRequestsRepositoryProvider.overrideWithValue(repo),
        ecclesiasticalYearsProvider.overrideWith((ref, activeOnly) async => []),
        userClassesProvider.overrideWith((ref) async => classes),
      ],
    );

int _currentStep(WidgetTester tester) =>
    tester.widget<SacStepPath>(find.byType(SacStepPath)).current;

void main() {
  setUpAll(initInvestitureTestEnv);

  group('hero', () {
    testWidgets(
        'pending: three steps, the scheduled date and what happens next',
        (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..ownHistory = [_entry('p', PersonStatus.pending)];
      await _pump(tester, repo);

      expect(find.byKey(const ValueKey('own-hero')), findsOneWidget);
      expect(find.text('En espera de autorización'), findsOneWidget);
      expect(find.text('Requisitos'), findsOneWidget);
      expect(find.text('Enviado'), findsOneWidget);
      expect(find.text('Investido'), findsOneWidget);
      expect(_currentStep(tester), 1);
      expect(
        find.textContaining('programada para el domingo 15 de noviembre'),
        findsOneWidget,
      );
      expect(
          find.textContaining('cuando el pastor la autorice'), findsOneWidget);
    });

    testWidgets('invested: celebrates, says who authorized and quotes them',
        (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..ownHistory = [
          _entry(
            'i',
            PersonStatus.invested,
            comment: 'Felicidades, sigue así.',
            resolvedBy: 'Samuel Ibarra',
            resolvedAt: DateTime.utc(2026, 12, 14, 15),
          ),
        ];
      await _pump(tester, repo);

      expect(find.text('¡Investido!'), findsOneWidget);
      expect(_currentStep(tester), 2);
      expect(
        find.text('El camino rindió fruto. Autorizó Samuel Ibarra el 14 dic.'),
        findsOneWidget,
      );
      expect(find.text('«Felicidades, sigue así.»'), findsOneWidget);
    });

    testWidgets('invested without comment or authorizer has no quote',
        (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..ownHistory = [_entry('i', PersonStatus.invested)];
      await _pump(tester, repo);

      expect(find.text('El camino rindió fruto.'), findsOneWidget);
      expect(find.byKey(const ValueKey('own-hero-comment')), findsNothing);
    });

    testWidgets('invested offers the next class when it can be derived',
        (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..ownHistory = [_entry('i', PersonStatus.invested)];
      await _pump(
        tester,
        repo,
        classes: const [
          ProgressiveClass(id: 3, name: 'Amigo', clubTypeId: 1),
          ProgressiveClass(id: 4, name: 'Compañero', clubTypeId: 1),
        ],
      );

      expect(find.text('Siguiente clase: Compañero'), findsOneWidget);
    });

    testWidgets('no next class when none is enrolled', (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..ownHistory = [_entry('i', PersonStatus.invested)];
      await _pump(tester, repo);

      expect(find.byKey(const ValueKey('own-next-class')), findsNothing);
    });

    for (final status in [
      PersonStatus.rejected,
      PersonStatus.rejectedByPerson,
      PersonStatus.rejectedBySystem,
    ]) {
      testWidgets('$status: talk to your leadership, never the reason',
          (tester) async {
        final repo = FakeInvestitureRequestsRepository()
          ..ownHistory = [
            _entry(
              'r',
              status,
              systemReason: 'Al comprobar el avance, esta persona no cubría',
              rejectionReason: 'Faltan evidencias del módulo 2',
            ),
          ];
        await _pump(tester, repo);

        expect(find.text('No investido'), findsWidgets);
        expect(
          find.text(
              'Falta de requisitos para investidura. Habla con tu directiva.'),
          findsOneWidget,
        );
        expect(find.textContaining('no cubría'), findsNothing);
        expect(find.textContaining('Faltan evidencias'), findsNothing);
      });
    }

    testWidgets('a pending entry is the hero even when an older one exists',
        (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..ownHistory = [
          _entry('old', PersonStatus.invested, className: 'Amigo', yearId: 8),
          _entry('new', PersonStatus.pending,
              className: 'Compañero', classId: 4),
        ];
      await _pump(tester, repo);

      expect(find.text('En espera de autorización'), findsOneWidget);
      expect(_currentStep(tester), 1);
    });
  });

  group('Mis clases', () {
    testWidgets('lists every class, most recent year first', (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..ownHistory = [
          _entry('old', PersonStatus.invested, className: 'Amigo', yearId: 8),
          _entry('new', PersonStatus.pending,
              className: 'Compañero', classId: 4, yearId: 9),
        ];
      await _pump(tester, repo);

      expect(find.text('MIS CLASES'), findsOneWidget);
      final first = tester.getTopLeft(find.text('Compañero'));
      final second = tester.getTopLeft(find.text('Amigo'));
      expect(first.dy, lessThan(second.dy));
      expect(find.text('En espera'), findsOneWidget);
      expect(find.text('Investido'), findsNWidgets(2));
    });

    testWidgets('a rejected class says to talk to the leadership',
        (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..ownHistory = [
          _entry('p', PersonStatus.pending, className: 'Compañero', classId: 4),
          _entry('r', PersonStatus.rejected, yearId: 8),
        ];
      await _pump(tester, repo);

      expect(
          find.textContaining('Faltaron requisitos. Habla con tu directiva.'),
          findsOneWidget);
      expect(find.text('No investido'), findsOneWidget);
    });

    testWidgets('the invested row shows who authorized', (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..ownHistory = [
          _entry('p', PersonStatus.pending, className: 'Compañero', classId: 4),
          _entry('i', PersonStatus.invested,
              yearId: 8, resolvedBy: 'Samuel Ibarra'),
        ];
      await _pump(tester, repo);

      expect(find.textContaining('Samuel Ibarra'), findsOneWidget);
    });
  });

  group('selection helpers', () {
    test('heroEntry prefers pending, then the most recent', () {
      final sorted = sortOwnEntries([
        _entry('a', PersonStatus.invested, yearId: 9),
        _entry('b', PersonStatus.pending, yearId: 8),
      ]);
      expect(heroEntry(sorted)?.personId, 'b');
      expect(heroEntry(const []), isNull);
      expect(
        heroEntry(sortOwnEntries([
          _entry('a', PersonStatus.invested, yearId: 8),
          _entry('c', PersonStatus.rejected, yearId: 9),
        ]))?.personId,
        'c',
      );
    });

    test('nextEnrolledClass picks the closest higher id not yet invested', () {
      const classes = [
        ProgressiveClass(id: 3, name: 'Amigo', clubTypeId: 1),
        ProgressiveClass(id: 6, name: 'Guía', clubTypeId: 1),
        ProgressiveClass(id: 4, name: 'Compañero', clubTypeId: 1),
        ProgressiveClass(
          id: 5,
          name: 'Explorador',
          clubTypeId: 1,
          investitureStatus: 'INVESTIDO',
        ),
      ];
      expect(nextEnrolledClass(classes, 3)?.name, 'Compañero');
      expect(nextEnrolledClass(classes, 4)?.name, 'Guía');
      expect(nextEnrolledClass(classes, 6), isNull);
    });
  });

  testWidgets('shows an empty state without entries', (tester) async {
    await _pump(tester, FakeInvestitureRequestsRepository());
    expect(find.text('Todavía no tienes investiduras'), findsOneWidget);
  });

  testWidgets('shows a retry state when loading fails', (tester) async {
    final repo = FakeInvestitureRequestsRepository()
      ..readFailure = const ServerFailure(message: 'Falló el servidor');
    await _pump(tester, repo);
    expect(find.text('No pudimos cargar tu investidura'), findsOneWidget);

    repo
      ..readFailure = null
      ..ownHistory = [_entry('p', PersonStatus.pending)];
    await tester.tap(find.text('Reintentar'));
    await settle(tester);
    expect(find.text('En espera de autorización'), findsOneWidget);
  });

  testWidgets('offline says so', (tester) async {
    final repo = FakeInvestitureRequestsRepository()
      ..readFailure = const ConnectionFailure(message: 'timeout');
    await _pump(tester, repo);
    expect(find.text('Sin conexión'), findsOneWidget);
  });
}
