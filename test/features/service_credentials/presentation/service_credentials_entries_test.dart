import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/service_credentials/domain/entities/service_credential_review.dart';
import 'package:sacdia_app/features/service_credentials/presentation/widgets/service_credentials_entries.dart';

import '../service_credentials_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  late FakeServiceCredentialsRepository repo;
  setUp(() {
    repo = FakeServiceCredentialsRepository()
      ..queue = (_, __, ___) => Right(reviewPage(
            const [],
            counts: const ReviewCounts(pending: 3),
          ));
  });

  const mine = 'Mis constancias';
  const review = 'Constancias por revisar';

  Future<void> openProfile(
    WidgetTester tester,
    UserEntity user, {
    bool acting = false,
  }) =>
      pumpCredentialsApp(
        tester,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: ServiceCredentialsProfileEntry(horizontalPadding: 16),
          ),
        ),
        overrides: credentialOverrides(repo, user: user, acting: acting),
      );

  group('profile entry', () {
    testWidgets('an adult without capability sees only Mis constancias',
        (tester) async {
      await openProfile(tester, adultUser());
      expect(find.text(mine), findsOneWidget);
      expect(find.text(review), findsNothing);
      // No count is requested for a person who cannot review.
      expect(repo.calls, isEmpty);

      await tester.tap(find.text(mine));
      await tester.pumpAndSettle();
      expect(find.text('route:/service-credentials'), findsOneWidget);
    });

    testWidgets('a reviewer sees both entries with the pending badge',
        (tester) async {
      await openProfile(tester, adultUser(capabilities: [reviewerCapability]));
      expect(find.text(mine), findsOneWidget);
      expect(find.text(review), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      await tester.tap(find.text(review));
      await tester.pumpAndSettle();
      expect(find.text('route:/service-credentials/review'), findsOneWidget);
    });

    testWidgets('no badge when nothing is pending', (tester) async {
      repo.queue = (_, __, ___) => Right(reviewPage(
            const [],
            counts: const ReviewCounts(),
          ));
      await openProfile(tester, adultUser(capabilities: [reviewerCapability]));
      expect(find.text(review), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('a failing count never hides the entry or shows an error',
        (tester) async {
      repo.queue = (_, __, ___) => const Left(serverFailure);
      await openProfile(tester, adultUser(capabilities: [reviewerCapability]));
      expect(find.text(review), findsOneWidget);
      expect(find.text('3'), findsNothing);
    });

    testWidgets('a pastor without club only gets the review entry',
        (tester) async {
      await openProfile(
        tester,
        adultUser(
          capabilities: ['admin_panel.pastor_only', reviewerCapability],
          withClub: false,
        ),
      );
      expect(find.text(mine), findsNothing);
      expect(find.text(review), findsOneWidget);
    });

    testWidgets('hidden while acting for a dependent, even for a reviewer',
        (tester) async {
      await openProfile(
        tester,
        adultUser(capabilities: [reviewerCapability]),
        acting: true,
      );
      expect(find.text(mine), findsNothing);
      expect(find.text(review), findsNothing);
      expect(find.text('CONSTANCIAS'), findsNothing);
      expect(repo.calls, isEmpty);
    });

    for (final (label, user) in [
      (
        'supervised teen',
        adultUser(
          capabilities: [reviewerCapability],
          kind: PrincipalKind.supervisedUser,
          supervision: SupervisionStatus.active,
        )
      ),
      (
        'pending teen',
        adultUser(
          capabilities: [reviewerCapability],
          kind: PrincipalKind.supervisedUser,
          supervision: SupervisionStatus.pendingGuardian,
        )
      ),
      (
        'linked device',
        adultUser(
            capabilities: [reviewerCapability],
            kind: PrincipalKind.linkedDevice)
      ),
      (
        'restricted account',
        adultUser(
            capabilities: [reviewerCapability], kind: PrincipalKind.unknown)
      ),
    ]) {
      testWidgets('hidden for a $label', (tester) async {
        await openProfile(tester, user);
        expect(find.text(mine), findsNothing);
        expect(find.text(review), findsNothing);
        expect(repo.calls, isEmpty);
      });
    }
  });

  group('coordination hub card', () {
    Future<void> openCard(WidgetTester tester, UserEntity user) =>
        pumpCredentialsApp(
          tester,
          home: const Scaffold(body: ServiceCredentialsReviewCard()),
          overrides: credentialOverrides(repo, user: user),
        );

    testWidgets('shown with the capability, with the pending badge',
        (tester) async {
      await openCard(tester, adultUser(capabilities: [reviewerCapability]));
      expect(find.text(review), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      await tester.tap(find.text(review));
      await tester.pumpAndSettle();
      expect(find.text('route:/service-credentials/review'), findsOneWidget);
    });

    testWidgets('hidden without the capability', (tester) async {
      await openCard(tester, adultUser());
      expect(find.text(review), findsNothing);
      expect(repo.calls, isEmpty);
    });
  });
}
