import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/members/domain/entities/join_request.dart';
import 'package:sacdia_app/features/members/presentation/widgets/join_request_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> translations;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    translations = jsonDecode(
      await File('assets/translations/es.json').readAsString(),
    ) as Map<String, dynamic>;
  });

  JoinRequest buildRequest({
    JoinRequestStatus status = JoinRequestStatus.pending,
    JoinRequestConsent? consent,
  }) {
    return JoinRequest(
      assignmentId: 'req-1',
      userId: 'user-1',
      name: 'Ana',
      paternalSurname: 'Ruiz',
      status: status,
      requestedAt: DateTime(2026, 9, 12),
      consent: consent,
    );
  }

  Future<void> pumpCard(
    WidgetTester tester, {
    JoinRequestStatus status = JoinRequestStatus.pending,
    JoinRequestConsent? consent,
    VoidCallback? onApprove,
    VoidCallback? onReject,
  }) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('es')],
        path: 'assets/translations',
        fallbackLocale: const Locale('es'),
        assetLoader: _TestAssetLoader(translations),
        child: Builder(
          builder: (context) => MaterialApp(
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            home: Scaffold(
              body: JoinRequestCard(
                request: buildRequest(status: status, consent: consent),
                onApprove: onApprove,
                onReject: onReject,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('pending actions sit on one compact row', (tester) async {
    await pumpCard(
      tester,
      onApprove: () {},
      onReject: () {},
    );

    expect(find.text('Ana Ruiz'), findsOneWidget);
    expect(find.bySemanticsLabel('Rechazar'), findsOneWidget);
    expect(find.bySemanticsLabel('Aprobar'), findsOneWidget);
    expect(find.text('Pendiente'), findsNothing);
    expect(
      tester.getSize(find.byType(JoinRequestCard)).height,
      lessThanOrEqualTo(64),
    );
  });

  group('consent badge (FP-76)', () {
    testWidgets('a pending minor shows the badge and a verify action',
        (tester) async {
      await pumpCard(
        tester,
        consent: const JoinRequestConsent(
          status: JoinRequestConsentStatus.pending,
        ),
        onApprove: () {},
        onReject: () {},
      );

      expect(find.text('Menor · consentimiento pendiente'), findsOneWidget);
      expect(find.bySemanticsLabel('Verificar consentimiento'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Aprobar'),
        findsNothing,
        reason: 'a pending minor is not approved directly',
      );
      expect(find.bySemanticsLabel('Rechazar'), findsOneWidget);
    });

    testWidgets('a verified minor shows the badge and approves directly',
        (tester) async {
      await pumpCard(
        tester,
        consent: const JoinRequestConsent(
          status: JoinRequestConsentStatus.verified,
        ),
        onApprove: () {},
        onReject: () {},
      );

      expect(find.text('Menor · consentimiento verificado'), findsOneWidget);
      expect(find.bySemanticsLabel('Aprobar'), findsOneWidget);
      expect(find.bySemanticsLabel('Verificar consentimiento'), findsNothing);
    });

    testWidgets('an adult request has no badge and is unchanged',
        (tester) async {
      await pumpCard(tester, onApprove: () {}, onReject: () {});

      expect(find.textContaining('Menor ·'), findsNothing);
      expect(find.bySemanticsLabel('Aprobar'), findsOneWidget);
    });
  });

  testWidgets('approved status uses a badge and no action hits',
      (tester) async {
    await pumpCard(tester, status: JoinRequestStatus.approved);

    expect(find.text('Aprobado'), findsOneWidget);
    expect(find.bySemanticsLabel('Rechazar'), findsNothing);
    expect(find.bySemanticsLabel('Aprobar'), findsNothing);
  });
}

class _TestAssetLoader extends AssetLoader {
  const _TestAssetLoader(this.translations);

  final Map<String, dynamic> translations;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return translations;
  }
}
