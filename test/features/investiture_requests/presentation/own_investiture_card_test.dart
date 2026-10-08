import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/investiture_requests/domain/entities/own_investiture_entry.dart';
import 'package:sacdia_app/features/investiture_requests/domain/entities/person_status.dart';
import 'package:sacdia_app/features/investiture_requests/presentation/providers/investiture_requests_providers.dart';
import 'package:sacdia_app/features/investiture_requests/presentation/utils/own_investiture_selection.dart';
import 'package:sacdia_app/features/investiture_requests/presentation/widgets/own_investiture_card.dart';
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
    );

List<Override> _overrides(List<OwnInvestitureEntry> history) {
  final repo = FakeInvestitureRequestsRepository()..ownHistory = history;
  return [
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
  ];
}

Future<void> _pumpCard(
  WidgetTester tester,
  List<OwnInvestitureEntry> history,
) =>
    pumpApp(
      tester,
      Scaffold(
          body: ListView(children: const [OwnInvestitureCard(classId: 3)])),
      overrides: _overrides(history),
    );

const _pending = 'En espera de autorización.';
const _invested =
    'El camino rindió fruto. Ya estás investido, y esta noticia es para celebrarla.';
const _rejected = 'Falta de requisitos para investidura.';

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

  group('OwnInvestitureCard', () {
    testWidgets('renders nothing without an entry for the class',
        (tester) async {
      await _pumpCard(tester, [_entry(PersonStatus.pending, classId: 99)]);
      expect(find.text(_pending), findsNothing);
      expect(find.byType(OwnInvestitureEntryCard), findsNothing);
    });

    testWidgets('pending shows the closed text, class and date',
        (tester) async {
      await _pumpCard(tester, [_entry(PersonStatus.pending)]);
      expect(find.text(_pending), findsOneWidget);
      expect(find.textContaining('Amigo'), findsOneWidget);
      expect(find.textContaining('2026'), findsOneWidget);
      expect(find.text('En espera'), findsOneWidget);
    });

    testWidgets('invested celebrates, with the comment when it exists',
        (tester) async {
      await _pumpCard(tester, [
        _entry(PersonStatus.invested, authorizationComment: 'Felicitaciones'),
      ]);
      expect(find.text(_invested), findsOneWidget);
      expect(find.text('Felicitaciones'), findsOneWidget);
      expect(find.textContaining('Amigo'), findsOneWidget);
    });

    testWidgets('invested without comment shows no quote', (tester) async {
      await _pumpCard(tester, [_entry(PersonStatus.invested)]);
      expect(find.text(_invested), findsOneWidget);
      expect(find.text('Comentario de la autorización'), findsNothing);
    });

    for (final status in [
      PersonStatus.rejected,
      PersonStatus.rejectedByPerson,
      PersonStatus.rejectedBySystem,
    ]) {
      testWidgets('$status shows only the closed text, never the reason',
          (tester) async {
        await _pumpCard(tester, [
          _entry(
            status,
            rejectionReason: 'Faltan evidencias del módulo 2',
            systemReason:
                'Al comprobar el avance, esta persona no cubría los requisitos mínimos.',
            personText: 'Texto interno del servidor',
          ),
        ]);
        expect(find.text(_rejected), findsOneWidget);
        expect(find.textContaining('Faltan evidencias'), findsNothing);
        expect(find.textContaining('no cubría'), findsNothing);
        expect(find.textContaining('Texto interno'), findsNothing);
        expect(find.textContaining('Rechaz'), findsNothing);
        expect(find.textContaining('Amigo'), findsOneWidget);
      });
    }

    testWidgets('closed year says not invested in the year, no requirements',
        (tester) async {
      await _pumpCard(tester, [
        _entry(
          PersonStatus.closedYear,
          yearId: 8,
          systemReason: 'texto largo del sistema',
        ),
      ]);
      expect(find.text('No investido en 2025-2026'), findsOneWidget);
      expect(find.text(_rejected), findsNothing);
      expect(find.textContaining('texto largo'), findsNothing);
    });

    testWidgets('closed year falls back to the date year without a catalog',
        (tester) async {
      await _pumpCard(tester, [
        _entry(PersonStatus.closedYear,
            yearId: 77, date: DateTime(2024, 11, 3)),
      ]);
      expect(find.text('No investido en 2024'), findsOneWidget);
    });

    testWidgets('removed with person text shows that text', (tester) async {
      await _pumpCard(tester, [
        _entry(
          PersonStatus.removed,
          personText: 'Tu certificado histórico ya acredita esta clase.',
        ),
      ]);
      expect(
        find.text('Tu certificado histórico ya acredita esta clase.'),
        findsOneWidget,
      );
    });

    testWidgets('removed without person text renders nothing', (tester) async {
      await _pumpCard(tester, [_entry(PersonStatus.removed)]);
      expect(find.byType(OwnInvestitureEntryCard), findsNothing);
    });
  });
}
