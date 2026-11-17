import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/classes/domain/entities/class_with_progress.dart';
import 'package:sacdia_app/features/classes/domain/entities/progressive_class.dart';
import 'package:sacdia_app/features/classes/presentation/providers/classes_providers.dart';
import 'package:sacdia_app/features/classes/presentation/views/class_detail_with_progress_view.dart';
import 'package:sacdia_app/features/investiture_requests/domain/entities/own_investiture_entry.dart';
import 'package:sacdia_app/features/investiture_requests/domain/entities/person_status.dart';
import 'package:sacdia_app/features/investiture_requests/presentation/providers/investiture_requests_providers.dart';
import 'package:sacdia_app/features/investiture_requests/presentation/widgets/investiture_rows.dart';
import 'package:sacdia_app/features/investiture_requests/presentation/widgets/own_investiture_row.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';

import '../../investiture_requests/fake_investiture_requests_repository.dart';
import '../../investiture_requests/presentation/investiture_test_harness.dart';

const _classId = 3;

OwnInvestitureEntry _entry(PersonStatus status, {String? personText}) =>
    OwnInvestitureEntry(
      personId: 'p1',
      userId: 'u1',
      classId: _classId,
      className: 'Amigo',
      clubSectionId: 4,
      ecclesiasticalYearId: 9,
      investitureDate: DateTime(2026, 11, 15),
      status: status,
      personText: personText,
    );

Future<void> _pump(
  WidgetTester tester, {
  required String legacyStatus,
  List<OwnInvestitureEntry> history = const [],
  String? targetUserId,
  String role = 'director',
  Future<List<OwnInvestitureEntry>>? pendingHistory,
}) {
  final repo = FakeInvestitureRequestsRepository()..ownHistory = history;
  final data = ClassWithProgress(
    id: _classId,
    name: 'Amigo',
    clubTypeId: 2,
    enrollmentId: 55,
    investitureStatus: legacyStatus,
    overallProgress: 100,
  );
  return pumpApp(
    tester,
    ClassDetailWithProgressView(
      classId: _classId,
      enrollmentId: 55,
      targetUserId: targetUserId,
    ),
    overrides: [
      investitureRequestsRepositoryProvider.overrideWithValue(repo),
      if (pendingHistory != null)
        ownInvestitureHistoryProvider.overrideWith((ref) => pendingHistory),
      classWithProgressProvider.overrideWith((ref, query) async => data),
      classDetailProvider.overrideWith(
        (ref, classId) async =>
            const ProgressiveClass(id: _classId, name: 'Amigo', clubTypeId: 2),
      ),
      classHonorsProvider.overrideWith((ref, classId) async => const []),
      clubContextProvider.overrideWith(
        (ref) async => ClubContext(clubId: 1, sectionId: 4, roleName: role),
      ),
    ],
  );
}

const _legacySend = 'Enviar a validación';
const _legacyReady = 'Lista para enviar';
const _pending = 'Investidura en espera';

void main() {
  setUpAll(initInvestitureTestEnv);

  group('own class view', () {
    testWidgets('shows the authorization status and no legacy send action',
        (tester) async {
      await _pump(
        tester,
        legacyStatus: 'IN_PROGRESS',
        history: [_entry(PersonStatus.pending)],
      );

      expect(find.text(_pending), findsOneWidget);
      expect(find.text(_legacySend), findsNothing);
      expect(find.text(_legacyReady), findsNothing);
    });

    testWidgets('never offers the legacy send, even to a director',
        (tester) async {
      await _pump(tester, legacyStatus: 'IN_PROGRESS');

      expect(find.text(_legacySend), findsNothing);
      expect(find.text('Reenviar a validación'), findsNothing);
      expect(find.text(_legacyReady), findsNothing);
      expect(find.text(_pending), findsNothing);
    });

    testWidgets('the authorization status replaces the legacy card',
        (tester) async {
      await _pump(
        tester,
        legacyStatus: 'SUBMITTED_FOR_VALIDATION',
        history: [_entry(PersonStatus.invested)],
      );

      expect(find.text('Investido'), findsOneWidget);
      expect(find.text('Enviado a validación'), findsNothing);
    });

    testWidgets('a rejection shows only the closed sentence', (tester) async {
      await _pump(
        tester,
        legacyStatus: 'IN_PROGRESS',
        history: [_entry(PersonStatus.rejected)],
      );

      expect(find.text('No investido'), findsOneWidget);
      expect(find.text('Faltaron requisitos. Habla con tu directiva.'),
          findsOneWidget);
    });
  });

  group('after phase 8', () {
    const legacyLabels = {
      'SUBMITTED_FOR_VALIDATION': 'Enviado a validación',
      'CLUB_APPROVED': 'Aprobado por el club',
      'COORDINATOR_APPROVED': 'Aprobado por coordinador',
      'FIELD_APPROVED': 'Aprobado por campo',
      'APPROVED': 'Aprobado',
      'REJECTED': 'Observada',
    };

    for (final entry in legacyLabels.entries) {
      testWidgets('${entry.key} shows no legacy card in the own view',
          (tester) async {
        await _pump(tester, legacyStatus: entry.key);

        expect(find.text(entry.value), findsNothing);
        expect(find.text(_legacySend), findsNothing);
      });
    }

    testWidgets('a director viewing a member gets no legacy send action',
        (tester) async {
      await _pump(tester, legacyStatus: 'IN_PROGRESS', targetUserId: 'u99');

      expect(find.text(_legacySend), findsNothing);
      expect(find.text(_legacyReady), findsNothing);
    });

    testWidgets(
        'an INVESTIDO class without an authorization entry (certificate or '
        'legacy) shows ONE Investido row', (tester) async {
      await _pump(tester, legacyStatus: 'INVESTIDO');

      expect(find.byType(OwnInvestitureRow), findsOneWidget);
      expect(find.text('Investido'), findsOneWidget);
      expect(find.text('Investidura registrada'), findsOneWidget);
    });

    testWidgets('a member viewed by the board shows Investido read only',
        (tester) async {
      await _pump(tester, legacyStatus: 'INVESTIDO', targetUserId: 'u99');

      expect(find.text('Investido'), findsOneWidget);
      // No lleva a «Mi investidura»: esa pantalla es de quien mira.
      expect(find.byType(InvestitureChevron), findsNothing);
    });

    testWidgets('a member viewed by the board shows nothing when not invested',
        (tester) async {
      await _pump(
        tester,
        legacyStatus: 'IN_PROGRESS',
        targetUserId: 'u99',
        history: [_entry(PersonStatus.pending)],
      );

      expect(find.byType(InvestitureRow), findsNothing);
    });

    testWidgets('the authorization entry replaces the registered row',
        (tester) async {
      await _pump(
        tester,
        legacyStatus: 'INVESTIDO',
        history: [_entry(PersonStatus.invested)],
      );

      // Una sola fila: la del flujo de autorización.
      expect(find.byType(InvestitureRow), findsOneWidget);
      expect(find.text('Investido'), findsOneWidget);
      expect(find.text('Investidura registrada'), findsNothing);
    });

    testWidgets('a pending entry shows a single row with the date',
        (tester) async {
      await _pump(
        tester,
        legacyStatus: 'IN_PROGRESS',
        history: [_entry(PersonStatus.pending)],
      );

      expect(find.byType(InvestitureRow), findsOneWidget);
      expect(find.text('dom 15 nov · progreso bloqueado'), findsOneWidget);
    });
  });
}
