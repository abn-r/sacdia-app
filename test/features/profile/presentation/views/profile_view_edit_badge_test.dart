import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/profile/domain/entities/user_detail.dart';
import 'package:sacdia_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:sacdia_app/features/profile/presentation/views/edit_profile_view.dart';
import 'package:sacdia_app/features/profile/presentation/views/profile_view.dart';

import '../../../family/family_test_harness.dart';

class _FakeProfileNotifier extends ProfileNotifier {
  _FakeProfileNotifier(this.profile);

  final UserDetail profile;

  @override
  Future<UserDetail?> build() async => profile;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initLocalization);

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpFamilyApp(
      tester,
      overrides: [
        authNotifierProvider.overrideWith(FakeAuthNotifier.new),
        profileNotifierProvider.overrideWith(
          () => _FakeProfileNotifier(
            UserDetail(
              id: 'mateo-1',
              email: 'mateo@example.com',
              name: 'Mateo',
              paternalSurname: 'Herrera',
            ),
          ),
        ),
      ],
      routes: [GoRoute(path: '/', builder: (_, __) => const ProfileView())],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the "Actualizar perfil" button is gone', (tester) async {
    await pump(tester);

    expect(find.text('Mateo Herrera'), findsOneWidget);
    expect(find.text('Actualizar perfil'), findsNothing);
  });

  testWidgets('the avatar badge is an edit badge with the edit semantics',
      (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);

    expect(
      find.byKey(const ValueKey('profile-avatar-edit-badge')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Editar perfil'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('tapping the badge opens the edit profile screen',
      (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('profile-avatar-edit-badge')));
    await tester.pumpAndSettle();

    expect(find.byType(EditProfileView), findsOneWidget);
  });

  testWidgets('tapping the avatar opens the edit profile screen',
      (tester) async {
    await pump(tester);

    await tester.tap(find.text('MH'));
    await tester.pumpAndSettle();

    expect(find.byType(EditProfileView), findsOneWidget);
  });
}
