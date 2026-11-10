import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/members/domain/entities/role_candidate.dart';

import '../../members_test_support.dart';
import '../../role_candidates_test_support.dart';

RoleRequirement _req({
  RequirementMode mode = RequirementMode.info,
  RequirementStatus status = RequirementStatus.missing,
  bool enforced = false,
  String role = 'counselor',
}) =>
    RoleRequirement(
      role: role,
      mode: mode,
      status: status,
      enforced: enforced,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initLocalization);

  late FakeMembersRepository repo;

  setUp(() => repo = FakeMembersRepository());

  void loads(List<RoleCandidate> items) {
    repo.roleCandidatesResults = [Right(candidatesPage(items))];
  }

  Future<void> tapCandidate(WidgetTester tester) async {
    await tester.tap(find.text('Laura Méndez'));
    await tester.pumpAndSettle();
  }

  Future<void> openDetail(
    WidgetTester tester, {
    List<RoleRequirement> requirements = const [],
    List<RoleCandidateCredential> credentials = const [],
  }) async {
    final c = candidate(requirements: requirements);
    loads([c]);
    repo.roleCandidateDetailResult = Right(
      RoleCandidateDetail(candidate: c, credentials: credentials),
    );
    await openRoleCandidatesSheet(tester, repo);
    await tapCandidate(tester);
    await tester.tap(find.text('Ver detalle'));
    await tester.pumpAndSettle();
  }

  group('detail: Constancia de consejería', () {
    testWidgets('approved credential shows status and date', (tester) async {
      await openDetail(
        tester,
        requirements: [_req()],
        credentials: [
          RoleCandidateCredential(
            status: CredentialStatus.approved,
            completedAt: DateTime(2025, 8, 1),
          ),
        ],
      );

      expect(find.text('Constancia de consejería'), findsOneWidget);
      expect(find.text('Aprobada'), findsOneWidget);
      expect(find.textContaining('2025'), findsWidgets);
      expect(find.text('No es obligatoria por ahora'), findsOneWidget);
    });

    testWidgets('pending review', (tester) async {
      await openDetail(
        tester,
        credentials: const [
          RoleCandidateCredential(
            status: CredentialStatus.pendingReview,
          ),
        ],
      );

      expect(find.text('En revisión'), findsOneWidget);
    });

    testWidgets('rejected credential reads «Sin constancia»', (tester) async {
      await openDetail(
        tester,
        credentials: const [
          RoleCandidateCredential(
            status: CredentialStatus.rejected,
          ),
        ],
      );

      expect(find.text('Sin constancia'), findsOneWidget);
    });

    testWidgets(
        'no credential: muted empty note, no mode note without '
        'requirements', (tester) async {
      await openDetail(tester);

      expect(find.text('Constancia de consejería'), findsOneWidget);
      expect(find.text('Sin constancia'), findsOneWidget);
      expect(find.text('No es obligatoria por ahora'), findsNothing);
      expect(find.text('Se recomienda para este cargo'), findsNothing);
      expect(find.text('Obligatoria para asignar el cargo'), findsNothing);
    });

    testWidgets('WARN note', (tester) async {
      await openDetail(
        tester,
        requirements: [_req(mode: RequirementMode.warn)],
      );
      expect(find.text('Se recomienda para este cargo'), findsOneWidget);
    });

    testWidgets('BLOCK enforced note; the strictest requirement wins',
        (tester) async {
      await openDetail(
        tester,
        requirements: [
          _req(role: 'secretary'),
          _req(mode: RequirementMode.block, enforced: true),
        ],
      );
      expect(find.text('Obligatoria para asignar el cargo'), findsOneWidget);
      expect(find.text('No es obligatoria por ahora'), findsNothing);
    });

    testWidgets('BLOCK not enforced reads like WARN', (tester) async {
      await openDetail(
        tester,
        requirements: [_req(mode: RequirementMode.block)],
      );
      expect(find.text('Se recomienda para este cargo'), findsOneWidget);
    });
  });

  group('list row chip', () {
    Future<void> openList(
      WidgetTester tester,
      List<RoleRequirement> requirements,
    ) async {
      loads([candidate(requirements: requirements)]);
      await openRoleCandidatesSheet(tester, repo);
    }

    testWidgets('INFO never shows the chip', (tester) async {
      await openList(tester, [_req()]);
      expect(find.text('Sin constancia'), findsNothing);
    });

    testWidgets('WARN not met shows the chip', (tester) async {
      await openList(tester, [_req(mode: RequirementMode.warn)]);
      expect(find.text('Sin constancia'), findsOneWidget);
    });

    testWidgets('no allowed role: inert row says why', (tester) async {
      loads([
        candidate(
          allowed: const [],
          requirements: [
            _req(mode: RequirementMode.block, enforced: true),
          ],
        ),
      ]);
      await openRoleCandidatesSheet(tester, repo);

      expect(
        find.text('Sin cargos disponibles en esta sección · '
            'Falta constancia de consejería'),
        findsOneWidget,
      );
      await tester.tap(find.text('Laura Méndez'));
      await tester.pumpAndSettle();
      expect(find.text('Elegir cargo'), findsNothing);
    });

    testWidgets('BLOCK (enforced or not) not met shows the chip',
        (tester) async {
      await openList(tester, [
        _req(mode: RequirementMode.block, enforced: true),
      ]);
      expect(find.text('Sin constancia'), findsOneWidget);
    });

    testWidgets('met requirement shows no chip', (tester) async {
      await openList(tester, [
        _req(mode: RequirementMode.warn, status: RequirementStatus.met),
      ]);
      expect(find.text('Sin constancia'), findsNothing);
    });

    testWidgets('no requirements shows no chip', (tester) async {
      await openList(tester, const []);
      expect(find.text('Sin constancia'), findsNothing);
    });
  });

  group('step 2: enforced BLOCK', () {
    testWidgets('the role is disabled with its reason; others stay enabled',
        (tester) async {
      loads([
        candidate(
          allowed: const ['deputy-director', 'treasurer'],
          requirements: [
            _req(mode: RequirementMode.block, enforced: true),
          ],
        ),
      ]);
      await openRoleCandidatesSheet(tester, repo);
      await tapCandidate(tester);

      expect(find.text('Falta constancia de consejería'), findsOneWidget);
      await tester.tap(find.text('Consejero'));
      await tester.pumpAndSettle();
      expect(find.text('Confirmar cargo'), findsNothing);

      await tester.tap(find.text('Subdirector'));
      await tester.pumpAndSettle();
      expect(find.text('Confirmar cargo'), findsOneWidget);
    });

    testWidgets('BLOCK not enforced leaves the role as the server allowed it',
        (tester) async {
      loads([
        candidate(requirements: [_req(mode: RequirementMode.block)]),
      ]);
      await openRoleCandidatesSheet(tester, repo);
      await tapCandidate(tester);

      expect(find.text('Falta constancia de consejería'), findsNothing);
    });
  });

  group('step 3 notice', () {
    Future<void> toConfirm(
      WidgetTester tester,
      List<RoleRequirement> requirements,
    ) async {
      loads([candidate(requirements: requirements)]);
      await openRoleCandidatesSheet(tester, repo);
      await tapCandidate(tester);
      await tester.tap(find.text('Consejero'));
      await tester.pumpAndSettle();
    }

    const notice = 'Aún no tiene constancia de consejería aprobada';

    testWidgets('WARN not met shows the notice and still assigns',
        (tester) async {
      await toConfirm(tester, [_req(mode: RequirementMode.warn)]);

      expect(find.text(notice), findsOneWidget);
      await tester.tap(find.text('Asignar cargo'));
      await tester.pumpAndSettle();
      expect(repo.assignRoleCalls, [(userId: 'u1', role: 'counselor')]);
    });

    testWidgets('BLOCK not enforced shows the notice', (tester) async {
      await toConfirm(tester, [_req(mode: RequirementMode.block)]);
      expect(find.text(notice), findsOneWidget);
    });

    testWidgets('INFO, met, or another role shows no notice', (tester) async {
      await toConfirm(tester, [_req()]);
      expect(find.text(notice), findsNothing);
    });

    testWidgets('a requirement of another role shows no notice',
        (tester) async {
      await toConfirm(
        tester,
        [_req(mode: RequirementMode.warn, role: 'secretary')],
      );
      expect(find.text(notice), findsNothing);
    });
  });
}
