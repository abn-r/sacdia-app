import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:sacdia_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:sacdia_app/features/dashboard/presentation/views/dashboard_view.dart';
import 'package:sacdia_app/features/profile/domain/entities/user_detail.dart';
import 'package:sacdia_app/features/profile/presentation/providers/profile_providers.dart';

import '../../../family/family_test_harness.dart';

class _NullDashboardNotifier extends DashboardNotifier {
  @override
  Future<DashboardSummary?> build() async => null;
}

class _NullProfileNotifier extends ProfileNotifier {
  @override
  Future<UserDetail?> build() async => null;
}

const _pendingMinor = UserEntity(
  id: 'ana-1',
  email: 'ana@example.com',
  authorization: AuthorizationSnapshot(
    clubAssignments: [
      AuthorizationGrant(
        assignmentId: 'pending-1',
        status: 'pending',
        roleName: 'member',
        clubId: 1,
        sectionId: 2,
      ),
    ],
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  late FakeAuthNotifier auth;

  setUp(() => auth = FakeAuthNotifier(_pendingMinor));

  Future<void> pump(WidgetTester tester, {ActingForSession? session}) async {
    await pumpFamilyApp(
      tester,
      overrides: [
        dashboardNotifierProvider.overrideWith(_NullDashboardNotifier.new),
        authNotifierProvider.overrideWith(() => auth),
        profileNotifierProvider.overrideWith(_NullProfileNotifier.new),
        if (session != null)
          actingForSessionProvider.overrideWithValue(session),
      ],
      routes: [
        GoRoute(path: '/', builder: (_, __) => const DashboardView()),
        stubRoute(RouteNames.family),
        stubRoute(RouteNames.homeProfile),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('not acting: the original second-person copy and profile CTA',
      (tester) async {
    await pump(tester);

    expect(find.text('Solicitud enviada'), findsOneWidget);
    expect(find.textContaining('Tu solicitud para unirte al club'),
        findsOneWidget);
    expect(find.textContaining('formación personal'), findsOneWidget);
    expect(find.text('Ir a mi perfil'), findsOneWidget);
    expect(find.text('Ir a Mi familia'), findsNothing);
  });

  testWidgets(
      'acting for a minor: third person with the name, no personal-formation '
      'sentence, and the CTA is Mi familia', (tester) async {
    await pump(
      tester,
      session: ActingForSession()
        ..enter(const ActingDependent(userId: 'ana-1', firstName: 'Ana')),
    );

    expect(
      find.text(
        'La solicitud de Ana para unirse al club fue enviada. El director la '
        'revisará junto con la ficha de consentimiento firmada. Si aún no la '
        'entregas, llévala al club o súbela desde Mi familia.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Tu solicitud'), findsNothing);
    expect(find.textContaining('formación personal'), findsNothing);
    expect(find.text('Ir a mi perfil'), findsNothing);
    expect(find.text('Ir a Mi familia'), findsOneWidget);
  });

  testWidgets('the CTA exits acting first and then opens Mi familia',
      (tester) async {
    await pump(
      tester,
      session: ActingForSession()
        ..enter(const ActingDependent(userId: 'ana-1', firstName: 'Ana')),
    );

    await tester.tap(find.text('Ir a Mi familia'));
    await tester.pumpAndSettle();

    expect(auth.switchCalls, [(id: null, firstName: null)]);
    expect(find.text('route:${RouteNames.family}'), findsOneWidget);
  });

  test('the acting variants exist in the 4 locales and take the name', () {
    for (final locale in ['es', 'en', 'fr', 'pt-BR']) {
      final json = jsonDecode(
        File('assets/translations/$locale.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final pending = (json['dashboard']
          as Map<String, dynamic>)['pending_state'] as Map<String, dynamic>;
      expect(pending['body_acting'], contains('{name}'), reason: locale);
      expect(pending['family_action_acting'], isNotEmpty, reason: locale);
    }
  });
}
