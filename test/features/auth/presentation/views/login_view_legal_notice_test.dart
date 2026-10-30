import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/widgets/sac_legal_consent.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/auth/presentation/views/login_view.dart';
import '../../../../support/riverpod_test_support.dart';

class _LoggedOutAuthNotifier extends AuthNotifier {
  @override
  Future<UserEntity?> build() async => null;
}

void main() {
  testWidgets('login shows the static legal notice (no checkbox)',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      testProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_LoggedOutAuthNotifier.new),
          socialSignInInFlightProvider.overrideWith((ref) => false),
        ],
        child: const MaterialApp(home: LoginView()),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    final notice = find.byType(SacLegalNoticeText);
    expect(notice, findsOneWidget);
    expect(tester.widget<SacLegalNoticeText>(notice).termsUrl,
        'https://sacdia.com/terms');
    expect(tester.widget<SacLegalNoticeText>(notice).privacyUrl,
        'https://sacdia.com/privacy');
    expect(find.byType(Checkbox), findsNothing);
  });
}
