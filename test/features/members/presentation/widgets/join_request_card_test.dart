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
  }) {
    return JoinRequest(
      assignmentId: 'req-1',
      userId: 'user-1',
      name: 'Ana',
      paternalSurname: 'Ruiz',
      status: status,
      requestedAt: DateTime(2026, 9, 12),
    );
  }

  Future<void> pumpCard(
    WidgetTester tester, {
    JoinRequestStatus status = JoinRequestStatus.pending,
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
                request: buildRequest(status: status),
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
