import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/dashboard/presentation/widgets/for_you_section.dart';
import '../../../../support/l10n_test_support.dart';
import '../../../../support/riverpod_test_support.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._user);

  final UserEntity _user;

  @override
  Future<UserEntity?> build() async => _user;
}

UserEntity _user({List<String> permissions = const []}) {
  return UserEntity(
    id: 'user-1',
    email: 'user@example.com',
    authorization: AuthorizationSnapshot(
      effectivePermissions: permissions,
      activeAssignmentId: 'a-1',
      clubAssignments: [
        AuthorizationGrant(
          assignmentId: 'a-1',
          roleName: 'member',
          clubId: 1,
          sectionId: 2,
          status: 'active',
        ),
      ],
    ),
  );
}

Future<void> _pump(WidgetTester tester, UserEntity user) async {
  await tester.pumpWidget(
    testProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(() => _FakeAuthNotifier(user)),
      ],
      child: const MaterialApp(
        home: Scaffold(
            body: Padding(
          padding: EdgeInsets.all(20),
          child: ForYouSection(),
        )),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(loadSpanishTranslations);

  testWidgets('a club member sees the four tiles in four equal columns',
      (tester) async {
    await _pump(tester, _user(permissions: const ['resources:read']));

    expect(find.text('Para ti'), findsOneWidget);
    expect(find.text('Especialidades'), findsOneWidget);
    expect(find.text('Logros'), findsOneWidget);
    expect(find.text('Credencial'), findsOneWidget);
    expect(find.text('Recursos'), findsOneWidget);
    expect(find.byType(SacCard), findsNWidgets(4));

    final widths = tester
        .widgetList<SacCard>(find.byType(SacCard))
        .map((card) => tester.getSize(find.byWidget(card)).width)
        .toSet();
    expect(widths, hasLength(1), reason: 'columns must be equal width');
  });

  testWidgets('every tile is exposed as a labelled button', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _user(permissions: const ['resources:read']));

    for (final label in [
      'Especialidades',
      'Logros',
      'Credencial',
      'Recursos'
    ]) {
      expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
    }
    handle.dispose();
  });

  testWidgets('without access to resources the row has three columns',
      (tester) async {
    // Without `resources:read` the catalog hides "resources-list".
    await _pump(tester, _user());

    expect(find.text('Recursos'), findsNothing);
    expect(find.text('Especialidades'), findsOneWidget);
    expect(find.text('Logros'), findsOneWidget);
    expect(find.text('Credencial'), findsOneWidget);
    expect(find.byType(SacCard), findsNWidgets(3));
  });
}
