import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
// ignore: unnecessary_import
import 'package:sacdia_app/core/providers/riverpod_aliases.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/auth/presentation/providers/login_notice_provider.dart';
import 'package:sacdia_app/features/auth/presentation/views/login_view.dart';

import '../../../family/family_test_harness.dart';

class _RecordingAuth extends AuthNotifier {
  final signIns = <({String identifier, String password})>[];

  @override
  Future<UserEntity?> build() async => null;

  @override
  Future<bool> signIn({
    required String identifier,
    required String password,
  }) async {
    signIns.add((identifier: identifier, password: password));
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  Future<_RecordingAuth> pumpLogin(
    WidgetTester tester, {
    List<Override> extra = const [],
  }) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final auth = _RecordingAuth();
    await pumpFamilyApp(
      tester,
      overrides: [authNotifierProvider.overrideWith(() => auth), ...extra],
      routes: [
        GoRoute(path: '/', builder: (_, __) => const LoginView()),
      ],
    );
    await tester.pump(const Duration(seconds: 2));
    return auth;
  }

  Future<void> submit(WidgetTester tester) async {
    final button = tester.widgetList<SacButton>(find.byType(SacButton)).first;
    button.onPressed?.call();
    await tester.pump();
  }

  testWidgets('the field says "Correo o usuario" and shows no email hint',
      (tester) async {
    await pumpLogin(tester);

    expect(find.text('Correo o usuario'), findsOneWidget);
    expect(find.text('Correo electrónico'), findsNothing);
  });

  testWidgets('a handle is sent as typed: no email-format validation',
      (tester) async {
    final auth = await pumpLogin(tester);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'ana-7kq4m9');
    await tester.enterText(fields.at(1), 'Password123');
    await tester.pump();
    await submit(tester);

    expect(auth.signIns.single.identifier, 'ana-7kq4m9');
    expect(auth.signIns.single.password, 'Password123');
    expect(find.textContaining('correo válido'), findsNothing);
  });

  testWidgets('an email is still accepted', (tester) async {
    final auth = await pumpLogin(tester);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'ana@example.com');
    await tester.enterText(fields.at(1), 'Password123');
    await tester.pump();
    await submit(tester);

    expect(auth.signIns.single.identifier, 'ana@example.com');
  });

  testWidgets('an empty identifier is rejected before the network',
      (tester) async {
    final auth = await pumpLogin(tester);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(1), 'Password123');
    await tester.pump();
    await submit(tester);

    expect(auth.signIns, isEmpty);
    expect(find.text('Ingresa tu correo o tu usuario'), findsOneWidget);
  });

  testWidgets('an identifier over 254 characters is rejected locally',
      (tester) async {
    final auth = await pumpLogin(tester);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'a' * 255);
    await tester.enterText(fields.at(1), 'Password123');
    await tester.pump();
    await submit(tester);

    expect(auth.signIns, isEmpty);
    expect(find.text('Es demasiado largo'), findsOneWidget);
  });

  testWidgets('the revoked-access notice explains why the session ended',
      (tester) async {
    await pumpLogin(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(LoginView)),
    );

    container.read(loginNoticeProvider.notifier).state =
        LoginNotice.supervisedAccessRevoked;
    await tester.pump();

    expect(
      find.textContaining('Tu tutor desactivó o cambió tu acceso'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pump();

    expect(container.read(loginNoticeProvider), isNull);
    expect(
      find.textContaining('Tu tutor desactivó o cambió tu acceso'),
      findsNothing,
    );
  });
}
