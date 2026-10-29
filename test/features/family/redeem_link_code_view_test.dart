import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/post_registration/presentation/widgets/relationship_type_picker_field.dart';
import 'package:sacdia_app/features/family/presentation/views/redeem_link_code_view.dart';

import 'family_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initLocalization);

  late FakeFamilyRepository repo;
  late FakeAuthNotifier auth;

  setUp(() {
    repo = FakeFamilyRepository();
    auth = FakeAuthNotifier();
  });

  Future<GoRouter> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = await pumpFamilyApp(
      tester,
      overrides: familyOverrides(repo: repo, auth: auth),
      initialLocation: '/family',
      routes: [
        stubRoute('/family'),
        GoRoute(
          path: '/family/link',
          builder: (_, __) => const RedeemLinkCodeView(),
        ),
      ],
    );
    router.push('/family/link');
    await tester.pumpAndSettle();
    return router;
  }

  SacButton submit(WidgetTester tester) =>
      tester.widget<SacButton>(find.widgetWithText(SacButton, 'Vincular'));

  Future<void> fill(WidgetTester tester, {String code = '7kq4-m9tx'}) async {
    await tester.enterText(find.byType(TextFormField).first, code);
    await tester.tap(find.byType(RelationshipTypePickerField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Madre').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
  }

  testWidgets('the relationship picker uses only the guardianship types',
      (tester) async {
    await pump(tester);

    expect(find.text('Tu parentesco con el menor'), findsOneWidget);
    await tester.tap(find.byType(RelationshipTypePickerField));
    await tester.pumpAndSettle();

    expect(find.text('Madre'), findsWidgets);
    expect(find.text('Primo'), findsNothing);
  });

  testWidgets('submit needs a code, a relationship and the sworn declaration',
      (tester) async {
    await pump(tester);
    expect(submit(tester).onPressed, isNull);

    await fill(tester);

    expect(submit(tester).onPressed, isNotNull);
  });

  testWidgets('redeems in any case and returns to Mi familia with a message',
      (tester) async {
    final router = await pump(tester);
    await fill(tester, code: '7kq4 m9tx');

    await tester.tap(find.text('Vincular'));
    await tester.pumpAndSettle();

    expect(repo.redeemCalls.single.code, '7kq4 m9tx');
    expect(repo.redeemCalls.single.relationshipTypeId, 'rel-1');
    expect(router.state.uri.path, '/family');
    expect(find.text('Ya puedes gestionar el perfil de Ana.'), findsOneWidget);
  });

  testWidgets('an invalid code shows ONE generic message', (tester) async {
    repo.redeemed = const Left(
      ServerFailure(
        message: 'x',
        code: 400,
        errorCode: 'GUARDIANSHIP_LINK_CODE_INVALID',
      ),
    );
    await pump(tester);
    await fill(tester);

    await tester.tap(find.text('Vincular'));
    await tester.pumpAndSettle();

    expect(
      find.text('El código no es válido o ya no está disponible.'),
      findsOneWidget,
    );
  });

  testWidgets('a locked user is told to try later', (tester) async {
    repo.redeemed = const Left(
      ServerFailure(
        message: 'x',
        code: 429,
        errorCode: 'GUARDIANSHIP_LINK_CODE_LOCKED',
      ),
    );
    await pump(tester);
    await fill(tester);

    await tester.tap(find.text('Vincular'));
    await tester.pumpAndSettle();

    expect(
      find.text('Demasiados intentos. Intenta de nuevo más tarde.'),
      findsOneWidget,
    );
  });

  testWidgets('already a guardian', (tester) async {
    repo.redeemed = const Left(
      ServerFailure(
        message: 'x',
        code: 409,
        errorCode: 'GUARDIANSHIP_ALREADY_GUARDIAN',
      ),
    );
    await pump(tester);
    await fill(tester);

    await tester.tap(find.text('Vincular'));
    await tester.pumpAndSettle();

    expect(find.text('Ya eres tutor de este menor.'), findsOneWidget);
  });

  testWidgets('a minor guardian gets the message and a way to fix the profile',
      (tester) async {
    repo.redeemed = const Left(
      ServerFailure(
        message: 'x',
        code: 422,
        errorCode: 'GUARDIANSHIP_GUARDIAN_NOT_ADULT',
      ),
    );
    await pump(tester);
    await fill(tester);

    await tester.tap(find.text('Vincular'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Debes ser mayor de edad'), findsOneWidget);
    expect(find.text('Completar mi perfil'), findsOneWidget);
  });

  testWidgets('redeeming your own code is explained', (tester) async {
    repo.redeemed = const Left(
      AuthFailure(
        message: 'x',
        code: 403,
        errorCode: 'GUARDIANSHIP_LINK_CODE_SELF_REDEEM',
      ),
    );
    await pump(tester);
    await fill(tester);

    await tester.tap(find.text('Vincular'));
    await tester.pumpAndSettle();

    expect(
      find.text('No puedes canjear un código que tú mismo generaste.'),
      findsOneWidget,
    );
  });
}
