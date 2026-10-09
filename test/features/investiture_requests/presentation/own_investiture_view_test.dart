import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/investiture_requests/domain/entities/own_investiture_entry.dart';
import 'package:sacdia_app/features/investiture_requests/domain/entities/person_status.dart';
import 'package:sacdia_app/features/investiture_requests/presentation/providers/investiture_requests_providers.dart';
import 'package:sacdia_app/features/investiture_requests/presentation/views/own_investiture_view.dart';
import 'package:sacdia_app/features/investiture_requests/presentation/widgets/own_investiture_card.dart';
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
    );

Future<void> _pump(
  WidgetTester tester,
  FakeInvestitureRequestsRepository repo,
) =>
    pumpApp(
      tester,
      const OwnInvestitureView(),
      overrides: [
        investitureRequestsRepositoryProvider.overrideWithValue(repo),
        ecclesiasticalYearsProvider.overrideWith((ref, activeOnly) async => []),
      ],
    );

void main() {
  setUpAll(initInvestitureTestEnv);

  testWidgets('lists the entries, most recent year first', (tester) async {
    final repo = FakeInvestitureRequestsRepository()
      ..ownHistory = [
        _entry('old', PersonStatus.invested, className: 'Amigo', yearId: 8),
        _entry('new', PersonStatus.pending, className: 'Compañero', yearId: 9),
      ];
    await _pump(tester, repo);

    expect(find.byType(OwnInvestitureEntryCard), findsNWidgets(2));
    final first = tester.getTopLeft(find.textContaining('Compañero'));
    final second = tester.getTopLeft(find.textContaining('Amigo'));
    expect(first.dy, lessThan(second.dy));
    expect(find.text('En espera de autorización.'), findsOneWidget);
  });

  testWidgets('never leaks the reason of a rejection', (tester) async {
    final repo = FakeInvestitureRequestsRepository()
      ..ownHistory = [
        _entry(
          'r',
          PersonStatus.rejected,
          systemReason: 'Al comprobar el avance, esta persona no cubría',
        ),
      ];
    await _pump(tester, repo);

    expect(find.text('Falta de requisitos para investidura.'), findsOneWidget);
    expect(find.textContaining('no cubría'), findsNothing);
  });

  testWidgets('shows an empty state without entries', (tester) async {
    await _pump(tester, FakeInvestitureRequestsRepository());
    expect(find.text('Todavía no tenés investiduras'), findsOneWidget);
  });

  testWidgets('shows a retry state when loading fails', (tester) async {
    final repo = FakeInvestitureRequestsRepository()
      ..readFailure = const ServerFailure(message: 'sin conexión');
    await _pump(tester, repo);
    expect(find.text('No pudimos cargar tu investidura'), findsOneWidget);

    repo
      ..readFailure = null
      ..ownHistory = [_entry('p', PersonStatus.pending)];
    await tester.tap(find.text('Reintentar'));
    await settle(tester);
    expect(find.text('En espera de autorización.'), findsOneWidget);
  });
}
