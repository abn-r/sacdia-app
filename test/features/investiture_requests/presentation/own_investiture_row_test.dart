import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/investiture_requests/domain/entities/own_investiture_entry.dart';
import 'package:sacdia_app/features/investiture_requests/domain/entities/person_status.dart';
import 'package:sacdia_app/features/investiture_requests/presentation/providers/investiture_requests_providers.dart';
import 'package:sacdia_app/features/investiture_requests/presentation/utils/own_investiture_selection.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/investiture_requests/presentation/widgets/own_investiture_row.dart';
import 'package:sacdia_app/providers/catalogs_provider.dart';
import 'package:sacdia_app/shared/models/catalogs/ecclesiastical_year_model.dart';

import '../fake_investiture_requests_repository.dart';
import 'investiture_test_harness.dart';

OwnInvestitureEntry _entry(
  PersonStatus status, {
  String id = 'p1',
  int classId = 3,
  int yearId = 9,
  DateTime? date,
  String? personText,
  String? authorizationComment,
  String? rejectionReason,
  String? systemReason,
  String? resolvedBy,
  DateTime? resolvedAt,
}) =>
    OwnInvestitureEntry(
      personId: id,
      userId: 'u1',
      classId: classId,
      className: 'Amigo',
      clubSectionId: 4,
      ecclesiasticalYearId: yearId,
      investitureDate: date ?? DateTime(2026, 11, 15),
      status: status,
      personText: personText,
      authorizationComment: authorizationComment,
      rejectionReason: rejectionReason,
      systemReason: systemReason,
      resolvedByName: resolvedBy,
      resolvedAt: resolvedAt,
    );

/// El detalle de clase monta la fila dentro de una columna con router.
Future<List<String>> _pumpRow(
  WidgetTester tester,
  List<OwnInvestitureEntry> history, {
  bool enrollmentInvested = false,
  Failure? readFailure,
}) async {
  final visited = <String>[];
  final repo = FakeInvestitureRequestsRepository()
    ..ownHistory = history
    ..readFailure = readFailure;
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(
          body: ListView(
            children: [
              OwnInvestitureRow(
                classId: 3,
                enrollmentInvested: enrollmentInvested,
              ),
            ],
          ),
        ),
      ),
      GoRoute(
        path: RouteNames.ownInvestiture,
        builder: (_, state) {
          visited.add(state.matchedLocation);
          return const Scaffold(body: Text('mi investidura'));
        },
      ),
    ],
  );
  await pumpRouterApp(
    tester,
    router,
    overrides: [
      investitureRequestsRepositoryProvider.overrideWithValue(repo),
      ecclesiasticalYearsProvider.overrideWith(
        (ref, activeOnly) async => [
          EcclesiasticalYearModel(
            ecclesiasticalYearId: 8,
            name: '2025-2026',
            startDate: DateTime(2025, 1, 1),
            endDate: DateTime(2025, 12, 31),
            active: false,
          ),
        ],
      ),
    ],
  );
  return visited;
}

void main() {
  setUpAll(initInvestitureTestEnv);

  group('selectOwnEntryForClass', () {
    test('keeps only the class and picks the most recent year', () {
      final picked = selectOwnEntryForClass([
        _entry(PersonStatus.invested, id: 'old', yearId: 8),
        _entry(PersonStatus.pending, id: 'new', yearId: 9),
        _entry(PersonStatus.invested, id: 'other', classId: 7, yearId: 10),
      ], 3);
      expect(picked?.personId, 'new');
    });

    test('within a year the latest date wins', () {
      final picked = selectOwnEntryForClass([
        _entry(PersonStatus.rejected, id: 'a', date: DateTime(2026, 10, 20)),
        _entry(PersonStatus.pending, id: 'b', date: DateTime(2026, 11, 20)),
      ], 3);
      expect(picked?.personId, 'b');
    });

    test('same year and date prefer pending over invested over the rest', () {
      final picked = selectOwnEntryForClass([
        _entry(PersonStatus.rejected, id: 'r'),
        _entry(PersonStatus.invested, id: 'i'),
        _entry(PersonStatus.pending, id: 'p'),
      ], 3);
      expect(picked?.personId, 'p');
    });

    test('ignores entries that carry nothing to show', () {
      expect(
        selectOwnEntryForClass([
          _entry(PersonStatus.removed),
          _entry(PersonStatus.removed, personText: '  '),
          _entry(PersonStatus.unknown),
        ], 3),
        isNull,
      );
      expect(
        selectOwnEntryForClass([
          _entry(PersonStatus.removed, personText: 'Aviso'),
        ], 3),
        isNotNull,
      );
    });
  });

  group('OwnInvestitureRow', () {
    testWidgets('renders nothing without an entry or an investiture',
        (tester) async {
      await _pumpRow(tester, [_entry(PersonStatus.pending, classId: 99)]);
      expect(find.text('Investidura en espera'), findsNothing);
      expect(find.text('Investido'), findsNothing);
    });

    testWidgets('pending: one row with the date and the locked progress',
        (tester) async {
      await _pumpRow(tester, [_entry(PersonStatus.pending)]);
      expect(find.text('Investidura en espera'), findsOneWidget);
      expect(find.text('dom 15 nov · progreso bloqueado'), findsOneWidget);
      expect(find.byType(OwnInvestitureRow), findsOneWidget);
    });

    testWidgets('invested through the flow says who authorized and when',
        (tester) async {
      await _pumpRow(tester, [
        _entry(
          PersonStatus.invested,
          resolvedBy: 'Samuel Ibarra',
          resolvedAt: DateTime.utc(2026, 12, 14, 15),
        ),
      ]);
      expect(find.text('Investido'), findsOneWidget);
      expect(find.text('Autorizó Samuel Ibarra el 14 dic'), findsOneWidget);
    });

    testWidgets(
        'invested by certificate (no entry) still shows one Investido row',
        (tester) async {
      await _pumpRow(tester, const [], enrollmentInvested: true);
      expect(find.text('Investido'), findsOneWidget);
      expect(find.text('Investidura registrada'), findsOneWidget);
    });

    testWidgets('an entry wins over the registered investiture',
        (tester) async {
      await _pumpRow(
        tester,
        [_entry(PersonStatus.pending)],
        enrollmentInvested: true,
      );
      expect(find.text('Investidura en espera'), findsOneWidget);
      expect(find.text('Investido'), findsNothing);
      expect(find.text('Investidura registrada'), findsNothing);
    });

    testWidgets('if the history fails, the registered investiture still shows',
        (tester) async {
      await _pumpRow(
        tester,
        const [],
        enrollmentInvested: true,
        readFailure: const ServerFailure(message: 'x'),
      );
      expect(find.text('Investido'), findsOneWidget);
    });

    for (final status in [
      PersonStatus.rejected,
      PersonStatus.rejectedByPerson,
      PersonStatus.rejectedBySystem,
    ]) {
      testWidgets('$status says talk to your leadership, never the reason',
          (tester) async {
        await _pumpRow(tester, [
          _entry(
            status,
            rejectionReason: 'Faltan evidencias del módulo 2',
            systemReason: 'Al comprobar el avance, no cubría los requisitos.',
            personText: 'Texto interno del servidor',
          ),
        ]);
        expect(find.text('No investido'), findsOneWidget);
        expect(find.text('Faltaron requisitos. Habla con tu directiva.'),
            findsOneWidget);
        expect(find.textContaining('Faltan evidencias'), findsNothing);
        expect(find.textContaining('no cubría'), findsNothing);
        expect(find.textContaining('Texto interno'), findsNothing);
      });
    }

    testWidgets('closed year says not invested in the year', (tester) async {
      await _pumpRow(tester, [
        _entry(PersonStatus.closedYear, yearId: 8, systemReason: 'texto largo'),
      ]);
      expect(find.text('No investido en 2025-2026'), findsOneWidget);
      expect(find.textContaining('texto largo'), findsNothing);
    });

    testWidgets('removed with person text shows that text', (tester) async {
      await _pumpRow(tester, [
        _entry(
          PersonStatus.removed,
          personText: 'Tu certificado histórico ya acredita esta clase.',
        ),
      ]);
      expect(find.text('Tu certificado histórico ya acredita esta clase.'),
          findsOneWidget);
    });

    testWidgets('removed without person text renders nothing', (tester) async {
      await _pumpRow(tester, [_entry(PersonStatus.removed)]);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('tapping the row opens Mi investidura', (tester) async {
      final visited = await _pumpRow(tester, [_entry(PersonStatus.pending)]);
      await tester.tap(find.text('Investidura en espera'));
      await settle(tester);
      expect(visited, [RouteNames.ownInvestiture]);
      expect(find.text('mi investidura'), findsOneWidget);
    });
  });
}
