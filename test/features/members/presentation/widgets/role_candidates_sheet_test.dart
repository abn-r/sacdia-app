import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/features/members/domain/entities/role_candidate.dart';
import 'package:sacdia_app/features/members/presentation/utils/role_candidate_labels.dart';
import 'package:sacdia_app/features/members/presentation/widgets/role_candidates_list_step.dart';
import 'package:sacdia_app/features/members/presentation/widgets/role_candidates_skeleton.dart';

import '../../members_test_support.dart';
import '../../role_candidates_test_support.dart';

/// Just past the search debounce.
final _debounced =
    kRoleCandidatesSearchDebounce + const Duration(milliseconds: 50);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initLocalization);

  late FakeMembersRepository repo;

  setUp(() => repo = FakeMembersRepository());

  void loads(List<RoleCandidate> items, {List<RoleSlot>? slots}) {
    repo.roleCandidatesResults = [
      Right(candidatesPage(items, slots: slots)),
    ];
  }

  Future<void> tapCandidate(WidgetTester tester, String name) async {
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  /// Ink of a text: its own style, else the default style around it.
  Color? textColor(WidgetTester tester, String text) {
    final finder = find.text(text).first;
    return tester.widget<Text>(finder).style?.color ??
        DefaultTextStyle.of(tester.element(finder)).style.color;
  }

  group('list', () {
    testWidgets('shows the skeleton while loading', (tester) async {
      repo.roleCandidatesGate = Completer<void>();
      loads([candidate()]);
      await pumpMembersApp(
        tester,
        overrides: openOverrides(repo),
        home: const OpenSheetHarness(),
      );
      await tester.tap(find.text('open-sheet'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(RoleCandidatesSkeleton), findsOneWidget);
      expect(find.bySemanticsLabel('Cargando Guías Mayores'), findsOneWidget);
      expect(find.text('Laura Méndez'), findsNothing);

      repo.roleCandidatesGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(RoleCandidatesSkeleton), findsNothing);
      expect(find.text('Laura Méndez'), findsOneWidget);
    });

    testWidgets(
        'an available person: name, age · service years, investiture tag, '
        'group title with the server count', (tester) async {
      loads([
        candidate(
          guideMajor: const RoleCandidateGuideMajor(
            basis: GuideMajorBasis.invested,
            investitureYear: '2019',
            advanced: true,
            instructor: true,
          ),
        ),
      ]);
      await openRoleCandidatesSheet(tester, repo);

      expect(find.text('Agregar directivo'), findsOneWidget);
      expect(find.text('Sin cargo este año · 4'), findsOneWidget);
      expect(find.text('Laura Méndez'), findsOneWidget);
      expect(find.text('34 años · 6 años de servicio'), findsOneWidget);
      expect(find.text('Investido 2019'), findsOneWidget);
      expect(find.text('Avanzado'), findsOneWidget);
      expect(find.text('Instructor'), findsOneWidget);
    });

    testWidgets('D2 labels for every basis', (tester) async {
      loads([
        candidate(
          id: 'a',
          name: 'Ana',
          guideMajor: const RoleCandidateGuideMajor(
            basis: GuideMajorBasis.invested,
          ),
        ),
        candidate(
          id: 'b',
          name: 'Beto',
          guideMajor: const RoleCandidateGuideMajor(
            basis: GuideMajorBasis.approved,
          ),
        ),
        candidate(
          id: 'c',
          name: 'Carla',
          guideMajor: const RoleCandidateGuideMajor(
            basis: GuideMajorBasis.activeEnrollment,
          ),
        ),
      ]);
      await openRoleCandidatesSheet(tester, repo);

      expect(find.text('Investido'), findsOneWidget);
      expect(find.text('GM aprobado, sin investir'), findsOneWidget);
      expect(find.text('GM en curso'), findsOneWidget);
    });

    testWidgets('slot pills: bounded 1/2, 1/1 and unbounded counselors',
        (tester) async {
      loads(
        [candidate()],
        slots: roleSlots(
          deputy: const RoleSlot(
            role: 'deputy-director',
            occupied: 1,
            max: 2,
            holders: ['Ana Ruiz'],
          ),
          secretary: const RoleSlot(
            role: 'secretary',
            occupied: 1,
            max: 1,
            holders: ['Jorge Pérez'],
          ),
        ),
      );
      await openRoleCandidatesSheet(tester, repo);

      expect(find.text('Subdirector 1/2'), findsOneWidget);
      expect(find.text('Secretario 1/1'), findsOneWidget);
      expect(find.text('Consejeros 3'), findsOneWidget);
      expect(find.text('Tesorero 0/1'), findsOneWidget);
    });

    testWidgets(
        'rows that cannot be acted on: same section dimmed, consent missing '
        'and not enrolled are inert', (tester) async {
      repo.roleCandidatesResults = [
        Right(
          candidatesPage([
            candidate(
              id: 'held',
              name: 'Pedro Gómez',
              group: RoleCandidateGroup.withRole,
              currentRoles: const [
                RoleCandidateCurrentRole(
                  sectionId: 163,
                  clubTypeName: 'Aventureros',
                  role: 'secretary',
                ),
              ],
            ),
            candidate(
              id: 'minor',
              name: 'Mía Ríos',
              age: 16,
              consent: const RoleCandidateConsent(
                required: true,
                verified: false,
              ),
              allowed: const [],
            ),
            candidate(
              id: 'out',
              name: 'Nora Díaz',
              group: RoleCandidateGroup.notEnrolled,
              allowed: const [],
              guideMajor: null,
              blockedReason: RoleCandidateBlockedReason.gmMembershipRequired,
            ),
          ]),
        ),
      ];
      await openRoleCandidatesSheet(tester, repo);

      expect(
          find.text('Secretario · Aventureros (esta sección)'), findsOneWidget);
      final dimmed = tester.widget<Opacity>(find
          .ancestor(
              of: find.text('Pedro Gómez'), matching: find.byType(Opacity))
          .first);
      expect(dimmed.opacity, lessThan(1));
      expect(find.text('Falta consentimiento'), findsOneWidget);
      expect(find.text('Sin inscripción 2026 · 1'), findsOneWidget);
      expect(find.text('Debe inscribirse primero en Guías Mayores'),
          findsOneWidget);

      for (final name in ['Pedro Gómez', 'Mía Ríos', 'Nora Díaz']) {
        await tapCandidate(tester, name);
        expect(find.text('Elegir cargo'), findsNothing, reason: name);
        expect(find.text('Agregar directivo'), findsOneWidget, reason: name);
      }
    });

    testWidgets(
        'a role held in another section reads «Consejero · Conquistadores»',
        (tester) async {
      loads([
        candidate(
          currentRoles: const [
            RoleCandidateCurrentRole(
              sectionId: 165,
              clubTypeName: 'Conquistadores',
              role: 'counselor',
            ),
          ],
        ),
      ]);
      await openRoleCandidatesSheet(tester, repo);

      expect(find.text('Consejero · Conquistadores'), findsOneWidget);
      expect(find.textContaining('esta sección'), findsNothing);
    });

    testWidgets('search is debounced and sent to the server', (tester) async {
      loads([candidate()]);
      await openRoleCandidatesSheet(tester, repo);
      final before = repo.roleCandidateCalls.length;

      await tester.enterText(find.byType(TextField), 'lau');
      await tester.pump(const Duration(milliseconds: 100));
      expect(repo.roleCandidateCalls.length, before,
          reason: 'still debouncing');

      await tester.pump(_debounced);
      await tester.pumpAndSettle();

      expect(repo.roleCandidateCalls.last.search, 'lau');
      expect(
          repo.roleCandidateCalls.last.filter, RoleCandidatesFilter.available);
    });

    testWidgets('filter chips ask the server for that group', (tester) async {
      loads([candidate()]);
      await openRoleCandidatesSheet(tester, repo);

      expect(find.text('Sin cargo'), findsOneWidget);
      expect(find.text('Con cargo'), findsOneWidget);
      expect(find.text('Sin inscripción'), findsOneWidget);

      await tester.tap(find.text('Con cargo'));
      await tester.pumpAndSettle();
      expect(
          repo.roleCandidateCalls.last.filter, RoleCandidatesFilter.withRole);

      await tester.tap(find.text('Sin inscripción'));
      await tester.pumpAndSettle();
      expect(
        repo.roleCandidateCalls.last.filter,
        RoleCandidatesFilter.notEnrolled,
      );
    });

    testWidgets('empty list and filtered-empty list say different things',
        (tester) async {
      loads(const []);
      await openRoleCandidatesSheet(tester, repo);
      expect(find.text('Nadie por aquí'), findsOneWidget);
      expect(find.text('Nadie de Guías Mayores está sin cargo este año.'),
          findsOneWidget);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump(_debounced);
      await tester.pumpAndSettle();

      expect(find.text('Sin coincidencias'), findsOneWidget);
      expect(find.text('Nadie por aquí'), findsNothing);
    });

    testWidgets('an error shows a retry that reloads', (tester) async {
      repo.roleCandidatesResults = [
        const Left(ServerFailure(message: 'boom', code: 500)),
        Right(candidatesPage([candidate()])),
      ];
      await openRoleCandidatesSheet(tester, repo);

      expect(find.text('No se pudo cargar la lista'), findsOneWidget);
      expect(find.text('Laura Méndez'), findsNothing);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Laura Méndez'), findsOneWidget);
      expect(find.text('No se pudo cargar la lista'), findsNothing);
    });

    testWidgets('has_gm_section false shows the no-GM-section state',
        (tester) async {
      repo.roleCandidatesResults = [
        Right(candidatesPage(
          const [],
          counts: const RoleCandidatesCounts(),
          section: const RoleCandidatesSection(
            id: 163,
            clubTypeId: 1,
            clubTypeName: 'Aventureros',
            yearName: '2026',
            hasGmSection: false,
          ),
        )),
      ];
      await openRoleCandidatesSheet(tester, repo);

      expect(find.text('Este club no tiene sección de Guías Mayores'),
          findsOneWidget);
      expect(find.text('Reintentar'), findsNothing);
    });

    testWidgets('a 404 is a regular error with retry', (tester) async {
      repo.roleCandidatesResults = [
        const Left(ServerFailure(message: 'x', code: 404)),
      ];
      await openRoleCandidatesSheet(tester, repo);

      expect(find.text('Este club no tiene sección de Guías Mayores'),
          findsNothing);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });

  group('step 2: roles', () {
    List<RoleSlot> slots() => roleSlots(
          deputy: const RoleSlot(
            role: 'deputy-director',
            occupied: 2,
            max: 2,
            holders: ['Jorge Pérez', 'Ana Ruiz'],
          ),
          secretary: const RoleSlot(
            role: 'secretary',
            occupied: 1,
            max: 1,
            holders: ['Luis Soto'],
          ),
          secretaryTreasurer: const RoleSlot(
            role: 'secretary-treasurer',
            max: 1,
            blockedBy: ['secretary'],
          ),
        );

    testWidgets(
        'lists the five roles; disabled ones say why, enabled ones show slots',
        (tester) async {
      loads([
        candidate(allowed: const ['treasurer', 'counselor'])
      ], slots: slots());
      await openRoleCandidatesSheet(tester, repo);
      await tapCandidate(tester, 'Laura Méndez');

      expect(find.text('Elegir cargo'), findsOneWidget);
      for (final role in [
        'Subdirector',
        'Secretario',
        'Tesorero',
        'Secretario-Tesorero',
        'Consejero',
      ]) {
        expect(find.text(role), findsOneWidget, reason: role);
      }
      expect(find.text('Ocupado por Jorge Pérez, Ana Ruiz'), findsOneWidget);
      expect(find.text('Ocupado por Luis Soto'), findsOneWidget);
      expect(find.text('No compatible con Secretario'), findsOneWidget);
      expect(find.text('0 de 1 ocupados'), findsOneWidget);
      expect(find.text('3 asignados'), findsOneWidget);

      // A disabled role does nothing.
      await tester.tap(find.text('Subdirector'));
      await tester.pumpAndSettle();
      expect(find.text('Confirmar cargo'), findsNothing);
      expect(find.text('Elegir cargo'), findsOneWidget);
    });

    testWidgets('back returns to the list keeping the loaded people',
        (tester) async {
      loads([candidate()], slots: slots());
      await openRoleCandidatesSheet(tester, repo);
      final calls = repo.roleCandidateCalls.length;
      await tapCandidate(tester, 'Laura Méndez');

      await tester.tap(find.byTooltip('Atrás'));
      await tester.pumpAndSettle();

      expect(find.text('Agregar directivo'), findsOneWidget);
      expect(find.text('Laura Méndez'), findsOneWidget);
      expect(repo.roleCandidateCalls.length, calls, reason: 'no reload');
    });

    testWidgets('«Ver detalle» shows history, training note, insurance, honors',
        (tester) async {
      loads([candidate()]);
      repo.roleCandidateDetailResult = Right(
        RoleCandidateDetail(
          candidate: candidate(),
          roleHistory: const [
            RoleHistoryEntry(
              yearName: '2025',
              clubTypeName: 'Conquistadores',
              role: 'counselor',
            ),
          ],
          certifications: [
            RoleCandidateCertification(
              name: 'Primeros auxilios',
              status: 'approved',
              certifiedAt: DateTime(2025, 3, 10),
            ),
          ],
          insurance: RoleCandidateInsurance(
            active: true,
            expiresAt: DateTime(2026, 12, 31),
          ),
          honorsCount: 12,
        ),
      );
      await openRoleCandidatesSheet(tester, repo);
      await tapCandidate(tester, 'Laura Méndez');

      await tester.tap(find.text('Ver detalle'));
      await tester.pumpAndSettle();

      expect(repo.roleCandidateDetailCalls, ['u1']);
      expect(find.text('Historial de cargos'), findsOneWidget);
      expect(find.text('Consejero'), findsOneWidget);
      expect(find.text('Conquistadores · 2025'), findsOneWidget);
      expect(find.text('Primeros auxilios'), findsOneWidget);
      expect(find.text('Capacitación: no es obligatoria por ahora'),
          findsOneWidget);
      expect(find.textContaining('Vigente hasta'), findsOneWidget);
      expect(find.text('12 especialidades'), findsOneWidget);
      expect(find.textContaining('@'), findsNothing);
    });

    testWidgets('a detail failure shows an error with retry', (tester) async {
      loads([candidate()]);
      await openRoleCandidatesSheet(tester, repo);
      await tapCandidate(tester, 'Laura Méndez');

      await tester.tap(find.text('Ver detalle'));
      await tester.pumpAndSettle();

      expect(find.text('No se pudo cargar el detalle'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });

  group('step 3: confirm', () {
    Future<void> toConfirm(
      WidgetTester tester, {
      List<RoleCandidateCurrentRole> currentRoles = const [],
    }) async {
      loads([candidate(currentRoles: currentRoles)]);
      await openRoleCandidatesSheet(tester, repo);
      await tapCandidate(tester, 'Laura Méndez');
      await tester.tap(find.text('Subdirector'));
      await tester.pumpAndSettle();
    }

    testWidgets('warns when the person already holds a role elsewhere (D4)',
        (tester) async {
      await toConfirm(
        tester,
        currentRoles: const [
          RoleCandidateCurrentRole(
            sectionId: 165,
            clubTypeName: 'Conquistadores',
            role: 'counselor',
          ),
        ],
      );

      expect(find.text('Confirmar cargo'), findsOneWidget);
      expect(
        find.text('Asignar a Laura Méndez como Subdirector en Aventureros.'),
        findsOneWidget,
      );
      expect(
        find.text('También tiene el cargo de Consejero en Conquistadores'),
        findsOneWidget,
      );
    });

    testWidgets('no warning without roles in other sections', (tester) async {
      await toConfirm(tester);

      expect(find.textContaining('También tiene el cargo'), findsNothing);
    });

    testWidgets(
        'confirm posts the assignment, closes and shows the success snackbar',
        (tester) async {
      await toConfirm(tester);

      await tester.tap(find.text('Asignar cargo'));
      await tester.pumpAndSettle();

      expect(repo.assignRoleCalls, [(userId: 'u1', role: 'deputy-director')]);
      expect(find.text('Confirmar cargo'), findsNothing);
      expect(find.text('Agregar directivo'), findsNothing);
      expect(find.text('Cargo asignado: Subdirector'), findsOneWidget);
    });

    testWidgets(
        'CLUB_ROLE_SLOT_LIMIT_REACHED: message inside the sheet, lists reload, '
        'back-to-list button', (tester) async {
      repo.assignRoleResult = const Left(
        ServerFailure(
          message: 'raw backend text',
          code: 409,
          errorCode: 'CLUB_ROLE_SLOT_LIMIT_REACHED',
        ),
      );
      await toConfirm(tester);
      final calls = repo.roleCandidateCalls.length;

      await tester.tap(find.text('Asignar cargo'));
      await tester.pumpAndSettle();

      expect(find.text('Ese cargo ya no tiene cupo. Actualizamos la lista.'),
          findsOneWidget);
      expect(find.text('raw backend text'), findsNothing);
      expect(find.text('Confirmar cargo'), findsOneWidget);
      expect(find.text('Asignar cargo'), findsNothing);
      expect(repo.roleCandidateCalls.length, greaterThan(calls),
          reason: 'the stale list is reloaded');

      await tester.tap(find.text('Volver a la lista'));
      await tester.pumpAndSettle();
      expect(find.text('Agregar directivo'), findsOneWidget);
    });

    testWidgets('an unknown failure shows the generic message and can retry',
        (tester) async {
      repo.assignRoleResult =
          const Left(ServerFailure(message: 'boom', code: 500));
      await toConfirm(tester);

      await tester.tap(find.text('Asignar cargo'));
      await tester.pumpAndSettle();

      expect(find.text('Error al asignar el cargo. Intenta de nuevo.'),
          findsOneWidget);
      expect(find.text('Asignar cargo'), findsOneWidget,
          reason: 'a generic error does not invalidate the picture');
    });
  });

  group('error code mapping', () {
    testWidgets('every code the POST can return has its own message',
        (tester) async {
      await pumpMembersApp(tester, home: const SizedBox());
      const expected = {
        'CLUB_ROLE_SLOT_LIMIT_REACHED':
            'Ese cargo ya no tiene cupo. Actualizamos la lista.',
        'CLUB_ROLE_EXCLUSIVE_CONFLICT':
            'Ese cargo no es compatible con otro cargo ya ocupado en la sección.',
        'CLUB_ROLE_GM_MEMBERSHIP_REQUIRED':
            'Esta persona debe estar inscrita en Guías Mayores este año para recibir el cargo.',
        'CLUB_ROLE_ALREADY_HELD':
            'Esta persona ya tiene un cargo en esta sección.',
        'CLUB_ROLE_SELF_ASSIGNMENT': 'No puedes asignarte un cargo a ti mismo.',
        'CLUB_ROLE_REQUIREMENT_MISSING':
            'Este cargo requiere una constancia de consejería aprobada. Actualizamos la lista.',
        'MR_CONSENT_NOT_VERIFIED':
            'No se puede asignar un cargo a este menor: el consentimiento de su tutor aún no está verificado.',
      };
      expected.forEach((code, message) {
        expect(
          roleAssignErrorMessage(
            ServerFailure(message: 'x', code: 409, errorCode: code),
          ),
          message,
          reason: code,
        );
      });
      expect(
        roleAssignErrorMessage(const ServerFailure(message: 'x', code: 500)),
        'Error al asignar el cargo. Intenta de nuevo.',
      );
    });
  });

  group('accent and layout', () {
    testWidgets('a light accent uses its onColor ink on chips, pills and CTA',
        (tester) async {
      final bees = SacAccent.byId('class.busy_bees');
      expect(bees.onColor, isNot(Colors.white),
          reason: 'sanity: a light accent');
      loads(
        [candidate()],
        slots: roleSlots(
          secretary: const RoleSlot(role: 'secretary', occupied: 1, max: 1),
        ),
      );
      await openRoleCandidatesSheet(
        tester,
        repo,
        theme: AppTheme.buildLight(bees),
      );

      // Selected filter chip.
      expect(textColor(tester, 'Sin cargo'), bees.onColor);
      // Full slot pill goes neutral: «no room», never «selected».
      expect(textColor(tester, 'Secretario 1/1'), isNot(bees.onColor));
      expect(textColor(tester, 'Secretario 1/1'), isNot(bees.dark));
      // Open slot pill is the quiet accent.
      expect(textColor(tester, 'Subdirector 0/2'), bees.dark);

      await tapCandidate(tester, 'Laura Méndez');
      await tester.tap(find.text('Subdirector'));
      await tester.pumpAndSettle();
      expect(textColor(tester, 'Asignar cargo'), bees.onColor);
    });

    testWidgets('fits a 402pt phone at 100% text without overflow',
        (tester) async {
      loads([
        candidate(
          name: 'María de los Ángeles Fernández-Villalobos Echeverría',
          currentRoles: const [
            RoleCandidateCurrentRole(
              sectionId: 165,
              clubTypeName: 'Conquistadores',
              role: 'secretary-treasurer',
            ),
          ],
          guideMajor: const RoleCandidateGuideMajor(
            basis: GuideMajorBasis.approved,
            advanced: true,
            instructor: true,
          ),
        ),
      ]);
      await openRoleCandidatesSheet(
        tester,
        repo,
        size: const Size(402, 874),
        textScale: 1,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.textContaining('María de los Ángeles'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Elegir cargo'), findsOneWidget);
    });
  });
}
