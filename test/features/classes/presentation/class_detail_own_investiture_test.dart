import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/classes/domain/entities/class_with_progress.dart';
import 'package:sacdia_app/features/classes/domain/entities/progressive_class.dart';
import 'package:sacdia_app/features/classes/presentation/providers/classes_providers.dart';
import 'package:sacdia_app/features/classes/presentation/views/class_detail_with_progress_view.dart';
import 'package:sacdia_app/features/investiture_requests/domain/entities/own_investiture_entry.dart';
import 'package:sacdia_app/features/investiture_requests/domain/entities/person_status.dart';
import 'package:sacdia_app/features/investiture_requests/presentation/providers/investiture_requests_providers.dart';
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
const _pending = 'En espera de autorización.';

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

    testWidgets('keeps informing about a legacy validation in flight',
        (tester) async {
      await _pump(tester, legacyStatus: 'SUBMITTED_FOR_VALIDATION');

      expect(find.text('Enviado a validación'), findsOneWidget);
      expect(find.text(_legacySend), findsNothing);
    });

    testWidgets('the authorization status replaces the legacy card',
        (tester) async {
      await _pump(
        tester,
        legacyStatus: 'SUBMITTED_FOR_VALIDATION',
        history: [_entry(PersonStatus.invested)],
      );

      expect(
        find.text(
          'El camino rindió fruto. Ya estás investido, y esta noticia es para celebrarla.',
        ),
        findsOneWidget,
      );
      expect(find.text('Enviado a validación'), findsNothing);
    });

    testWidgets('a rejection shows only the closed sentence', (tester) async {
      await _pump(
        tester,
        legacyStatus: 'IN_PROGRESS',
        history: [_entry(PersonStatus.rejected)],
      );

      expect(
          find.text('Falta de requisitos para investidura.'), findsOneWidget);
    });
  });

  group('viewing a member (legacy flow stays until phase 8)', () {
    testWidgets('a director still sees the legacy send action', (tester) async {
      await _pump(
        tester,
        legacyStatus: 'IN_PROGRESS',
        targetUserId: 'u99',
        history: [_entry(PersonStatus.pending)],
      );

      expect(find.text(_legacySend), findsOneWidget);
      // La tarjeta de la propia persona no se muestra al mirar a otro miembro.
      expect(find.text(_pending), findsNothing);
    });
  });
}
