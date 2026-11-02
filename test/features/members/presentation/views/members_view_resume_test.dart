// Guarda del workaround de Riverpod 3.3.2 en `MembersView`: la lista de
// solicitudes se refresca DESPUÉS del pop de la verificación y de un frame
// (`endOfFrame`). Invalidar al volver (o desde la ruta tapada) hace que
// Riverpod 3.3.2 reanude los providers de la lista en mitad de un build y salte
// "setState() or markNeedsBuild() called during build". Reproducción mínima del
// problema en `test/core/providers/riverpod_resume_test.dart`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:sacdia_app/features/members/presentation/views/consent_verification_view.dart';
import 'package:sacdia_app/features/members/presentation/views/members_view.dart';

import '../../members_test_support.dart';

const _director = UserEntity(
  id: 'director-1',
  email: 'director@example.com',
  name: 'Laura',
  postRegisterComplete: true,
  authorization: AuthorizationSnapshot(
    effectivePermissions: ['club_members:approve', 'club_roles:assign'],
    activeAssignmentId: 'asg-dir',
    clubAssignments: [
      AuthorizationGrant(
        assignmentId: 'asg-dir',
        roleName: 'director',
        clubId: 1,
        sectionId: 12,
        status: 'active',
      ),
    ],
  ),
);

class _FakeAuth extends AuthNotifier {
  @override
  Future<UserEntity?> build() async => _director;
}

class _EmptyContinuations extends AnnualContinuationsNotifier {
  @override
  Future<AnnualContinuationsState> build() async =>
      const AnnualContinuationsState(items: []);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initLocalization);

  testWidgets(
      'coming back from the consent verification refreshes the requests '
      'without a framework error', (tester) async {
    final repo = FakeMembersRepository()
      ..requests = [minorRequest(evidence: true)];
    await pumpMembersApp(
      tester,
      overrides: [
        authNotifierProvider.overrideWith(_FakeAuth.new),
        membersRepositoryProvider.overrideWithValue(repo),
        annualContinuationsNotifierProvider.overrideWith(
          _EmptyContinuations.new,
        ),
      ],
      home: const MembersView(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Solicitudes').first);
    await tester.pumpAndSettle();
    expect(find.text('Ana Pérez'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Verificar consentimiento'));
    await tester.pumpAndSettle();
    expect(find.byType(ConsentVerificationView), findsOneWidget);
    final callsBefore = repo.joinRequestSectionCalls.length;

    // Mientras la lista está tapada el servidor deja de listar la solicitud.
    repo.requests = [adultRequest()];
    Navigator.of(tester.element(find.byType(ConsentVerificationView))).pop();
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(ConsentVerificationView), findsNothing);
    expect(
      repo.joinRequestSectionCalls.length,
      greaterThan(callsBefore),
      reason: 'the list is refreshed once the verification is closed',
    );
    expect(find.text('Ana Pérez'), findsNothing);
  });
}
