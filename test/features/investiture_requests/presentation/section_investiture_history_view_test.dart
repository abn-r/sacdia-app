import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/features/investiture_requests/domain/entities/own_investiture_entry.dart';
import 'package:sacdia_app/features/investiture_requests/domain/entities/person_status.dart';
import 'package:sacdia_app/features/investiture_requests/domain/entities/yearbook_entry.dart';
import 'package:sacdia_app/features/investiture_requests/presentation/providers/investiture_requests_providers.dart';
import 'package:sacdia_app/features/investiture_requests/presentation/views/section_investiture_history_view.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:sacdia_app/providers/catalogs_provider.dart';
import 'package:sacdia_app/shared/models/catalogs/ecclesiastical_year_model.dart';

import '../fake_investiture_requests_repository.dart';
import 'investiture_test_harness.dart';

OwnInvestitureEntry _history(
  String id,
  String userId,
  PersonStatus status, {
  int yearId = 9,
  int classId = 3,
  String className = 'Amigo',
  DateTime? date,
  String? rejectionReason,
  String? systemReason,
}) =>
    OwnInvestitureEntry(
      personId: id,
      userId: userId,
      classId: classId,
      className: className,
      clubSectionId: 4,
      ecclesiasticalYearId: yearId,
      investitureDate: date ?? DateTime(2026, 11, 15),
      status: status,
      rejectionReason: rejectionReason,
      systemReason: systemReason,
    );

YearbookEntry _yearbook(
  int enrollmentId,
  String userId, {
  int yearId = 9,
  int classId = 3,
  String className = 'Amigo',
}) =>
    YearbookEntry(
      enrollmentId: enrollmentId,
      userId: userId,
      classId: classId,
      className: className,
      ecclesiasticalYearId: yearId,
    );

EcclesiasticalYearModel _year(int id, String name) => EcclesiasticalYearModel(
      ecclesiasticalYearId: id,
      name: name,
      startDate: DateTime(2000 + id, 1, 1),
      endDate: DateTime(2000 + id, 12, 31),
      active: false,
    );

List<Override> _overrides(
  FakeInvestitureRequestsRepository repo, {
  String role = 'director',
  Map<String, String> names = const {},
}) =>
    [
      investitureRequestsRepositoryProvider.overrideWithValue(repo),
      clubContextProvider.overrideWith(
        (ref) async => ClubContext(clubId: 1, sectionId: 4, roleName: role),
      ),
      sectionPeopleNamesProvider.overrideWithValue(names),
      ecclesiasticalYearsProvider.overrideWith(
        (ref, activeOnly) async =>
            [_year(8, '2024-2025'), _year(9, '2025-2026')],
      ),
    ];

Future<void> _pump(
  WidgetTester tester,
  FakeInvestitureRequestsRepository repo, {
  String role = 'director',
  Map<String, String> names = const {},
}) =>
    pumpApp(
      tester,
      const SectionInvestitureHistoryView(),
      overrides: _overrides(repo, role: role, names: names),
    );

void main() {
  setUpAll(initInvestitureTestEnv);

  testWidgets('groups the history by year (newest first) and class',
      (tester) async {
    final repo = FakeInvestitureRequestsRepository()
      ..sectionHistory = [
        _history('a', 'u1', PersonStatus.invested, yearId: 8),
        _history('b', 'u2', PersonStatus.invested,
            yearId: 9, classId: 4, className: 'Compañero'),
        _history('c', 'u3', PersonStatus.invested, yearId: 9),
      ];
    await _pump(
      tester,
      repo,
      names: {'u1': 'Ana Pérez', 'u2': 'Beto Gómez', 'u3': 'Carla Ruiz'},
    );

    expect(find.text('2025-2026'), findsOneWidget);
    expect(find.text('2024-2025'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('2025-2026')).dy,
      lessThan(tester.getTopLeft(find.text('2024-2025')).dy),
    );
    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.text('Beto Gómez'), findsOneWidget);
    // Cada clase del año reciente tiene su propio encabezado.
    expect(find.text('Compañero'), findsOneWidget);
    expect(find.text('Amigo'), findsNWidgets(2));
  });

  testWidgets(
      'shows the status and the human reason only when the API sends it',
      (tester) async {
    final repo = FakeInvestitureRequestsRepository()
      ..sectionHistory = [
        _history('a', 'u1', PersonStatus.invested),
        _history('b', 'u2', PersonStatus.rejectedByPerson,
            rejectionReason: 'Faltan evidencias del tercer requisito'),
        _history('c', 'u3', PersonStatus.rejectedBySystem),
        _history('d', 'u4', PersonStatus.closedYear),
      ];
    await _pump(
      tester,
      repo,
      names: {'u1': 'Ana', 'u2': 'Beto', 'u3': 'Carla', 'u4': 'Dani'},
    );

    expect(find.text('Investido'), findsOneWidget);
    expect(find.text('No investido'), findsNWidgets(2));
    expect(find.text('No investido en el año'), findsOneWidget);
    expect(
      find.textContaining('Faltan evidencias del tercer requisito'),
      findsOneWidget,
    );
    expect(find.textContaining('Motivo'), findsOneWidget);
  });

  testWidgets('falls back to a neutral name when the member is unknown',
      (tester) async {
    final repo = FakeInvestitureRequestsRepository()
      ..sectionHistory = [_history('a', 'ghost', PersonStatus.invested)];
    await _pump(tester, repo);
    expect(find.text('Persona sin nombre'), findsOneWidget);
  });

  testWidgets('shows an empty state without history', (tester) async {
    await _pump(tester, FakeInvestitureRequestsRepository());
    expect(find.byType(SacEmptyState), findsOneWidget);
    expect(
        find.text('Todavía no hay investiduras registradas'), findsOneWidget);
  });

  testWidgets('yearbook tab lists enrollments by year and class',
      (tester) async {
    final repo = FakeInvestitureRequestsRepository()
      ..yearbook = [
        _yearbook(1, 'u1', yearId: 8),
        _yearbook(2, 'u2', yearId: 9, classId: 4, className: 'Compañero'),
        _yearbook(3, 'u3', yearId: 9),
      ];
    await _pump(
      tester,
      repo,
      names: {'u1': 'Ana Pérez', 'u2': 'Beto Gómez', 'u3': 'Carla Ruiz'},
    );
    expect(find.text('Ana Pérez'), findsNothing);

    await tester.tap(find.text('Anuario'));
    await settle(tester);

    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.text('Beto Gómez'), findsOneWidget);
    expect(find.text('Carla Ruiz'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('2025-2026')).dy,
      lessThan(tester.getTopLeft(find.text('2024-2025')).dy),
    );
  });

  testWidgets('yearbook tab shows an empty state without enrollments',
      (tester) async {
    await _pump(tester, FakeInvestitureRequestsRepository());
    await tester.tap(find.text('Anuario'));
    await settle(tester);
    expect(find.text('El anuario todavía está vacío'), findsOneWidget);
  });

  testWidgets('shows a retry state when loading fails', (tester) async {
    final repo = FakeInvestitureRequestsRepository()
      ..readFailure = const ServerFailure(message: 'sin conexión');
    await _pump(tester, repo);
    expect(find.text('No pudimos cargar el historial'), findsOneWidget);

    repo
      ..readFailure = null
      ..sectionHistory = [_history('a', 'u1', PersonStatus.invested)];
    await tester.tap(find.text('Reintentar'));
    await settle(tester);
    expect(find.text('Investido'), findsOneWidget);
  });

  testWidgets('is restricted to the board', (tester) async {
    await _pump(
      tester,
      FakeInvestitureRequestsRepository(),
      role: 'deputy-director',
    );
    expect(find.text('Acceso restringido'), findsOneWidget);
    expect(find.text('Historial'), findsNothing);
  });
}
