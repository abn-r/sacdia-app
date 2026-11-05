import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/dashboard/presentation/widgets/for_you_section.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
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

Map<String, dynamic> _stats({int validated = 5, int inProgress = 3}) => {
      'total': validated + inProgress,
      'validated': validated,
      'completed': validated,
      'in_progress': inProgress,
    };

Future<void> _pump(
  WidgetTester tester,
  UserEntity user, {
  AsyncValue<Map<String, dynamic>>? stats,
}) async {
  await tester.pumpWidget(
    testProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(() => _FakeAuthNotifier(user)),
        userHonorStatsLocalProvider
            .overrideWithValue(stats ?? AsyncValue.data(_stats())),
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

  testWidgets('credential, honors and resources are stacked full width',
      (tester) async {
    await _pump(tester, _user(permissions: const ['resources:read']));

    expect(find.text('Para ti'), findsOneWidget);
    expect(find.text('Credencial'), findsOneWidget);
    expect(find.text('Tu código QR de miembro'), findsOneWidget);
    expect(find.text('Especialidades'), findsOneWidget);
    expect(find.text('3 en curso · 5 validadas'), findsOneWidget);
    expect(find.text('Recursos'), findsOneWidget);
    expect(find.text('Logros'), findsNothing);
    expect(find.byType(SacCard), findsNWidgets(3));

    final cards = tester.widgetList<SacCard>(find.byType(SacCard)).toList();
    final widths =
        cards.map((card) => tester.getSize(find.byWidget(card)).width).toSet();
    expect(widths, hasLength(1), reason: 'every card spans the full width');

    final tops =
        cards.map((card) => tester.getTopLeft(find.byWidget(card)).dy).toList();
    expect(tops, orderedEquals([...tops]..sort()),
        reason: 'credential first, then honors, then resources');
    expect(
      tester.getTopLeft(find.text('Credencial')).dy,
      lessThan(tester.getTopLeft(find.text('Especialidades')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Especialidades')).dy,
      lessThan(tester.getTopLeft(find.text('Recursos')).dy),
    );
  });

  testWidgets('honors progress bar shows validated over total', (tester) async {
    await _pump(tester, _user());

    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, closeTo(5 / 8, 0.0001));
  });

  testWidgets('every shortcut is exposed as a labelled button', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _user(permissions: const ['resources:read']));

    for (final label in [
      'Credencial. Tu código QR de miembro',
      'Especialidades. 3 en curso · 5 validadas',
      'Recursos. Manuales y guías',
    ]) {
      expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
    }
    handle.dispose();
  });

  testWidgets('without access to resources only two cards remain',
      (tester) async {
    // Without `resources:read` the catalog hides "resources-list".
    await _pump(tester, _user());

    expect(find.text('Recursos'), findsNothing);
    expect(find.text('Credencial'), findsOneWidget);
    expect(find.text('Especialidades'), findsOneWidget);
    expect(find.byType(SacCard), findsNWidgets(2));
  });

  testWidgets('with no honors started it invites to the catalog',
      (tester) async {
    await _pump(
      tester,
      _user(),
      stats: AsyncValue.data(_stats(validated: 0, inProgress: 0)),
    );

    expect(find.text('Explora el catálogo y empieza una'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('while honors load only the title is shown', (tester) async {
    await _pump(tester, _user(), stats: const AsyncValue.loading());

    expect(find.text('Especialidades'), findsOneWidget);
    expect(find.textContaining('en curso'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
