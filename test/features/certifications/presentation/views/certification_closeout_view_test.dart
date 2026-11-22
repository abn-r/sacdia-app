import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/widgets/evidence_staging/evidence_staging_manager.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification_status.dart';
import 'package:sacdia_app/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:sacdia_app/features/certifications/presentation/views/certification_closeout_view.dart';

import '../../../../support/l10n_test_support.dart';
import '../../../../support/riverpod_test_support.dart';
import '../certification_test_support.dart';

Future<void> _pump(
  WidgetTester tester,
  CertificationEnrollmentStatus status,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    testProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(FakeCertificationAuth.new),
        certificationProgressProvider.overrideWith(
          (ref, id) async => sampleProgress(status: status),
        ),
      ],
      child: const MaterialApp(
        home: CertificationCloseoutView(
          certificationId: kCertificationId,
          enrollmentId: kEnrollmentId,
          certificationName: 'Instructor de Conquistadores',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadSpanishTranslations);

  testWidgets(
      'looks like a requirement: title, panel, description, one file and '
      '«Enviar acta»', (tester) async {
    await _pump(tester, CertificationEnrollmentStatus.readyForCloseout);

    expect(find.text('Acta de la junta'), findsWidgets);
    expect(find.text('Hasta 1 archivo'), findsOneWidget);
    expect(find.text('Sin enviar'), findsOneWidget);
    expect(find.text('Paso 1 de 3 · Ver todos los estados'), findsOneWidget);
    expect(find.byKey(const ValueKey('certification-closeout-text')),
        findsOneWidget);
    expect(find.text('ARCHIVO'), findsOneWidget);
    expect(find.byType(EvidenceStagingManager), findsOneWidget);

    // The classic «Imagen» / «PDF» buttons are gone: one action.
    expect(find.text('Imagen'), findsNothing);
    expect(find.text('Enviar acta'), findsOneWidget);
    final send = tester.widget<SacButton>(
      find.byKey(const ValueKey('certification-closeout-send')),
    );
    expect(send.isEnabled, isFalse, reason: 'nothing to send yet');
  });

  testWidgets('sent back it says «Reenviar»', (tester) async {
    await _pump(tester, CertificationEnrollmentStatus.changesRequested);

    expect(find.text('Por corregir'), findsWidgets);
    expect(find.text('Reenviar'), findsOneWidget);
  });

  testWidgets('after sending: «En revisión final», read-only, no action',
      (tester) async {
    await _pump(tester, CertificationEnrollmentStatus.submittedForFinalReview);

    expect(find.text('En revisión final'), findsOneWidget);
    expect(find.byType(EvidenceStagingManager), findsNothing);
    expect(find.byKey(const ValueKey('certification-closeout-send')),
        findsNothing);
  });

  testWidgets('approved: «Certificada»', (tester) async {
    await _pump(tester, CertificationEnrollmentStatus.certified);

    expect(find.text('Certificada'), findsOneWidget);
    expect(find.text('Paso 3 de 3 · Ver todos los estados'), findsOneWidget);
    expect(find.byKey(const ValueKey('certification-closeout-send')),
        findsNothing);
  });
}
