import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/members/domain/entities/annual_continuation.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:sacdia_app/features/members/presentation/views/annual_continuations_view.dart';

import '../../members_test_support.dart';

const _minor = AnnualContinuation(
  userId: 'mia-1',
  name: 'Mia Menor',
  baseSectionId: 12,
  ecclesiasticalYearId: 2026,
  annualStatus: 'not_enrolled',
  eligibility: 'blocked',
  blockedReason: 'MR_CONSENT_NOT_VERIFIED',
  suggestedClass: SuggestedClass(status: 'resolved', classId: 201, code: 'AMG'),
);

class _FakeContinuations extends AnnualContinuationsNotifier {
  @override
  Future<AnnualContinuationsState> build() async =>
      const AnnualContinuationsState(items: [_minor]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initLocalization);

  group('MR_CONSENT_NOT_VERIFIED blocked reason', () {
    testWidgets('renders the translated reason, not the raw code',
        (tester) async {
      await pumpMembersApp(
        tester,
        overrides: [
          annualContinuationsNotifierProvider
              .overrideWith(_FakeContinuations.new),
        ],
        home: const Scaffold(body: AnnualContinuationsBody()),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Mia Menor'), findsOneWidget);
      expect(find.textContaining('consentimiento del tutor'), findsOneWidget);
      expect(find.textContaining('MR_CONSENT_NOT_VERIFIED'), findsNothing);
    });

    test('is translated in all four locales', () {
      for (final locale in const ['es', 'en', 'fr', 'pt-BR']) {
        final decoded = jsonDecode(
          File('assets/translations/$locale.json').readAsStringSync(),
        ) as Map<String, dynamic>;
        final reasons = decoded['members']['continuations']['blocked_reasons']
            as Map<String, dynamic>;
        final text = reasons['MR_CONSENT_NOT_VERIFIED'] as String?;
        expect(text, isNotNull, reason: locale);
        expect(text!.trim(), isNotEmpty, reason: locale);
        expect(text, isNot('MR_CONSENT_NOT_VERIFIED'), reason: locale);
      }
    });
  });
}
