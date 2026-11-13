import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/providers/riverpod_aliases.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/majority_release/domain/entities/released_entry.dart';
import 'package:sacdia_app/features/majority_release/presentation/providers/majority_release_providers.dart';
import 'package:sacdia_app/features/majority_release/presentation/views/guardian_released_history_view.dart';
import 'package:sacdia_app/features/majority_release/presentation/widgets/director_adult_claim_row.dart';
import 'package:sacdia_app/features/majority_release/presentation/widgets/majority_notice_banner.dart';
import 'package:sacdia_app/features/majority_release/presentation/widgets/released_history_tile.dart';

import '../family/family_test_harness.dart';
import 'majority_release_test_support.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

UserEntity _guardian({bool flag = true}) => UserEntity(
      id: 'g1',
      email: 'g@example.com',
      postRegisterComplete: true,
      principal: const PrincipalInfo(kind: PrincipalKind.user),
      familyFeatures: FamilyFeatures(majorityRelease: flag),
    );

UserEntity _teen({
  bool flag = true,
  bool sent = true,
  DateTime? majority,
}) =>
    UserEntity(
      id: 't1',
      email: 't@example.com',
      postRegisterComplete: true,
      serverMode: AccountMode.teenSupervised,
      principal: PrincipalInfo(
        kind: PrincipalKind.supervisedUser,
        supervision: SupervisionInfo(
          status: SupervisionStatus.active,
          majorityDate: majority,
          majorityNoticeSent: sent,
        ),
      ),
      familyFeatures: FamilyFeatures(majorityRelease: flag),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  late FakeMajorityReleaseRepository repo;
  setUp(() => repo = FakeMajorityReleaseRepository());

  List<Override> overrides(UserEntity? user) => [
        authNotifierProvider.overrideWith(() => RecordingAuth(user)),
        majorityReleaseRepositoryProvider.overrideWithValue(repo),
      ];

  group('GuardianReleasedHistoryView', () {
    Future<void> mount(WidgetTester tester) => pumpFamilyApp(
          tester,
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => const GuardianReleasedHistoryView(),
            ),
          ],
          overrides: overrides(_guardian()),
        );

    testWidgets('minimal entries: name and date only; purged is anonymous',
        (tester) async {
      repo.history = Right([
        ReleasedEntry(
          guardianshipId: 'gs-1',
          dependentUserId: 'd-1',
          displayName: 'Ana',
          relationshipTypeName: 'Madre',
          releasedAt: DateTime.utc(2026, 11, 10),
          canIssueClaim: true,
        ),
        ReleasedEntry(
          guardianshipId: 'gs-2',
          dependentUserId: 'd-2',
          releasedAt: DateTime.utc(2026, 10, 1),
        ),
      ]);
      await mount(tester);
      await _settle(tester);

      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Persona liberada'), findsOneWidget);
      // Solo quien puede recibir un código lo ofrece.
      expect(find.byKey(const ValueKey('family_history_generate_code')),
          findsOneWidget);
    });

    testWidgets('generate shows the code once in a sheet', (tester) async {
      repo.history = const Right([
        ReleasedEntry(
          guardianshipId: 'gs-1',
          dependentUserId: 'd-1',
          displayName: 'Ana',
          canIssueClaim: true,
        ),
      ]);
      await mount(tester);
      await _settle(tester);

      await tester
          .tap(find.byKey(const ValueKey('family_history_generate_code')));
      await _settle(tester);

      expect(repo.guardianIssues, ['d-1']);
      expect(find.byKey(const ValueKey('adult_claim_issued_code')),
          findsOneWidget);
      expect(find.text('AB12-CD34'), findsOneWidget);
    });

    testWidgets('a refused issue shows a message, no sheet', (tester) async {
      repo.guardianCode = const Left(ServerFailure(
        message: 'x',
        code: 404,
        errorCode: 'FAMILY_ADULT_CLAIM_NOT_RELEASED',
      ));
      repo.history = const Right([
        ReleasedEntry(
          guardianshipId: 'gs-1',
          dependentUserId: 'd-1',
          displayName: 'Ana',
          canIssueClaim: true,
        ),
      ]);
      await mount(tester);
      await _settle(tester);

      await tester
          .tap(find.byKey(const ValueKey('family_history_generate_code')));
      await _settle(tester);

      expect(
          find.byKey(const ValueKey('adult_claim_issued_code')), findsNothing);
      expect(
        find.text('Esta persona no puede reclamar su cuenta con un código.'),
        findsOneWidget,
      );
    });

    testWidgets('empty history says so', (tester) async {
      await mount(tester);
      await _settle(tester);
      expect(find.text('Nadie liberado'), findsOneWidget);
    });
  });

  group('ReleasedHistoryTile (Mi familia)', () {
    Future<GoRouter> mount(WidgetTester tester, UserEntity user) =>
        pumpFamilyApp(
          tester,
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => const Scaffold(body: ReleasedHistoryTile()),
            ),
            stubRoute(RouteNames.familyReleased),
          ],
          overrides: overrides(user),
        );

    testWidgets('hidden while the feature is off (FP4-67)', (tester) async {
      await mount(tester, _guardian(flag: false));
      await _settle(tester);
      expect(find.byKey(const ValueKey('family_released_history_entry')),
          findsNothing);
    });

    testWidgets('collapsed entry opens the history', (tester) async {
      final router = await mount(tester, _guardian());
      await _settle(tester);

      await tester
          .tap(find.byKey(const ValueKey('family_released_history_entry')));
      await _settle(tester);
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        RouteNames.familyReleased,
      );
    });
  });

  group('DirectorAdultClaimRow', () {
    testWidgets('issues for the section and shows the code once',
        (tester) async {
      await pumpFamilyApp(
        tester,
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(
              body: DirectorAdultClaimRow(
                clubSectionId: 7,
                dependentUserId: 'd-9',
                dependentName: 'Luis',
              ),
            ),
          ),
        ],
        overrides: overrides(_guardian()),
      );
      await _settle(tester);

      await tester
          .tap(find.byKey(const ValueKey('director_adult_claim_generate')));
      await _settle(tester);

      expect(repo.directorIssues, [(section: 7, user: 'd-9')]);
      expect(find.text('ZZ99-YY88'), findsOneWidget);
    });

    testWidgets('a refusal is a message, not a crash', (tester) async {
      repo.directorCode = const Left(ServerFailure(
        message: 'x',
        code: 404,
        errorCode: 'FAMILY_ADULT_CLAIM_NOT_RELEASED',
      ));
      await pumpFamilyApp(
        tester,
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(
              body: DirectorAdultClaimRow(
                clubSectionId: 7,
                dependentUserId: 'd-9',
                dependentName: 'Luis',
              ),
            ),
          ),
        ],
        overrides: overrides(_guardian()),
      );
      await _settle(tester);

      await tester
          .tap(find.byKey(const ValueKey('director_adult_claim_generate')));
      await _settle(tester);
      expect(find.text('ZZ99-YY88'), findsNothing);
    });
  });

  group('MajorityNoticeSlot (teen notice)', () {
    Future<void> mount(WidgetTester tester, UserEntity user) => pumpFamilyApp(
          tester,
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => const Scaffold(body: MajorityNoticeSlot()),
            ),
          ],
          overrides: overrides(user),
        );

    testWidgets('shows the date and can be dismissed', (tester) async {
      await mount(tester, _teen(majority: DateTime(2026, 12, 1)));
      await _settle(tester);

      expect(
          find.byKey(const ValueKey('majority_notice_banner')), findsOneWidget);
      expect(find.textContaining('2026'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('majority_notice_dismiss')));
      await _settle(tester);
      expect(
          find.byKey(const ValueKey('majority_notice_banner')), findsNothing);
    });

    testWidgets('nothing with the flag off, without notice or for an adult',
        (tester) async {
      for (final user in [
        _teen(flag: false, majority: DateTime(2026, 12, 1)),
        _teen(sent: false, majority: DateTime(2026, 12, 1)),
        _teen(majority: null),
        _guardian(),
      ]) {
        await mount(tester, user);
        await _settle(tester);
        expect(
            find.byKey(const ValueKey('majority_notice_banner')), findsNothing);
      }
    });
  });
}
