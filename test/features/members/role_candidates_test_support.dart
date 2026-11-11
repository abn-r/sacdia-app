import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/providers/riverpod_aliases.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/members/domain/entities/role_candidate.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:sacdia_app/features/members/presentation/widgets/role_candidates_sheet.dart';

import 'members_test_support.dart';

/// Sección de Aventureros (id 163) del club 1: la que recibe el cargo.
const roleCandidatesContext = ClubContext(
  clubId: 1,
  sectionId: 163,
  clubTypeId: 1,
  clubTypeName: 'Aventureros',
);

const roleCandidatesSection = RoleCandidatesSection(
  id: 163,
  clubTypeId: 1,
  clubTypeName: 'Aventureros',
  yearName: '2026',
);

/// Los cinco cargos de servicio con cupo libre salvo donde se indique.
List<RoleSlot> roleSlots({
  RoleSlot? deputy,
  RoleSlot? secretary,
  RoleSlot? treasurer,
  RoleSlot? secretaryTreasurer,
  RoleSlot? counselor,
}) =>
    [
      deputy ?? const RoleSlot(role: 'deputy-director', max: 2),
      secretary ?? const RoleSlot(role: 'secretary', max: 1),
      treasurer ?? const RoleSlot(role: 'treasurer', max: 1),
      secretaryTreasurer ?? const RoleSlot(role: 'secretary-treasurer', max: 1),
      counselor ?? const RoleSlot(role: 'counselor', occupied: 3),
    ];

RoleCandidate candidate({
  String id = 'u1',
  String name = 'Laura Méndez',
  RoleCandidateGroup group = RoleCandidateGroup.available,
  List<String> allowed = const ['deputy-director', 'treasurer', 'counselor'],
  List<RoleCandidateCurrentRole> currentRoles = const [],
  RoleCandidateConsent? consent,
  RoleCandidateGuideMajor? guideMajor = const RoleCandidateGuideMajor(
    basis: GuideMajorBasis.invested,
    investitureYear: '2019',
  ),
  int? age = 34,
  int? serviceYears = 6,
  String? blockedReason,
  List<RoleRequirement> requirements = const [],
}) =>
    RoleCandidate(
      userId: id,
      name: name,
      group: group,
      age: age,
      serviceYears: serviceYears,
      guideMajor: guideMajor,
      currentRoles: currentRoles,
      consent: consent,
      allowedRoles: allowed,
      blockedReason: blockedReason,
      requirements: requirements,
    );

RoleCandidatesPage candidatesPage(
  List<RoleCandidate> items, {
  List<RoleSlot>? slots,
  int? total,
  int page = 1,
  RoleCandidatesCounts counts = const RoleCandidatesCounts(
    available: 4,
    withRole: 3,
  ),
  RoleCandidatesSection section = roleCandidatesSection,
}) =>
    RoleCandidatesPage(
      section: section,
      slots: slots ?? roleSlots(),
      items: items,
      page: page,
      total: total ?? items.length,
      counts: counts,
    );

/// Minimal screen with a button that opens the sheet.
class OpenSheetHarness extends ConsumerWidget {
  const OpenSheetHarness({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The members list is watched in the real screen; it keeps the notifier
    // alive while the sheet assigns.
    ref.watch(membersNotifierProvider);
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => showRoleCandidatesSheet(
            context,
            clubContext: roleCandidatesContext,
          ),
          child: const Text('open-sheet'),
        ),
      ),
    );
  }
}

/// Overrides every test of the sheet needs: the fake repository and a club
/// context (so the members notifier builds without auth).
List<Override> openOverrides(FakeMembersRepository repo) => [
      membersRepositoryProvider.overrideWithValue(repo),
      clubContextProvider.overrideWith((ref) async => roleCandidatesContext),
    ];

/// Opens the «Agregar directivo» sheet over a minimal scaffold.
Future<void> openRoleCandidatesSheet(
  WidgetTester tester,
  FakeMembersRepository repo, {
  Size size = const Size(800, 2400),
  double textScale = 0.5,
  ThemeData? theme,
  List<Override> extraOverrides = const [],
}) async {
  await pumpMembersApp(
    tester,
    size: size,
    textScale: textScale,
    theme: theme,
    overrides: [...openOverrides(repo), ...extraOverrides],
    home: const OpenSheetHarness(),
  );
  await tester.tap(find.text('open-sheet'));
  await tester.pumpAndSettle();
}

Either<Failure, RoleCandidatesPage> ok(RoleCandidatesPage page) => Right(page);
