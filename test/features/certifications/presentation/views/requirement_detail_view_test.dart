import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/widgets/evidence_staging/evidence_staging_manager.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification_activity_option.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification_requirement.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification_requirement_component.dart';
import 'package:sacdia_app/features/certifications/presentation/providers/certification_requirement_providers.dart';
import 'package:sacdia_app/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:sacdia_app/features/certifications/presentation/views/requirement_detail_view.dart';

import '../../../../support/l10n_test_support.dart';
import '../../../../support/riverpod_test_support.dart';
import '../certification_test_support.dart';

const _textComponent = CertificationRequirementComponent(
  componentId: 1,
  type: CertificationComponentType.textResponse,
  label: 'Describe cómo planificas una reunión de club',
  required: true,
);

const _filesComponent = CertificationRequirementComponent(
  componentId: 2,
  type: CertificationComponentType.fileEvidence,
  label: 'Adjunta tu plan',
  required: true,
  configuration: {'max_files': 3},
  evidences: [
    CertificationComponentEvidence(
      evidenceId: 31,
      originalFilename: 'plan.pdf',
      mimeType: 'application/pdf',
      sizeBytes: 1200,
    ),
    CertificationComponentEvidence(
      evidenceId: 32,
      originalFilename: 'anexo.pdf',
      mimeType: 'application/pdf',
      sizeBytes: 800,
    ),
  ],
);

const _activityComponent = CertificationRequirementComponent(
  componentId: 3,
  type: CertificationComponentType.linkedActivity,
  label: 'Actividad dirigida por ti',
  required: true,
);

const _attestationComponent = CertificationRequirementComponent(
  componentId: 4,
  type: CertificationComponentType.attestation,
  label: 'Constancia',
  required: true,
);

final _activities = [
  CertificationActivityOption(
    activityId: 91,
    name: 'Campamento de otoño',
    activityDate: DateTime(2026, 3, 1),
    clubName: 'Club Orión',
  ),
  CertificationActivityOption(
    activityId: 92,
    name: 'Feria de especialidades',
    activityDate: DateTime(2026, 4, 12),
  ),
];

class _Env {
  _Env(this.repo, this.drafts);

  final FakeCertificationsRepository repo;
  final FakeDraftSource drafts;
}

Future<_Env> _pump(
  WidgetTester tester,
  CertificationRequirement requirement,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repo = FakeCertificationsRepository()
    ..requirement = requirement
    ..activityOptions = _activities;
  final drafts = FakeDraftSource();
  await tester.pumpWidget(
    testProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(FakeCertificationAuth.new),
        certificationsRepositoryProvider.overrideWithValue(repo),
        certificationDraftLocalDataSourceProvider.overrideWithValue(drafts),
        certificationProgressProvider.overrideWith(
          (ref, id) async => sampleProgress(),
        ),
      ],
      child: const MaterialApp(
        home: CertificationRequirementDetailView(
          certificationId: kCertificationId,
          sectionId: 22,
          enrollmentId: kEnrollmentId,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Env(repo, drafts);
}

const _sendKey = ValueKey('certification-send');

bool _sendEnabled(WidgetTester tester) =>
    tester.widget<SacButton>(find.byKey(_sendKey)).isEnabled;

void main() {
  setUpAll(loadSpanishTranslations);

  group('written answer', () {
    testWidgets(
        'status panel, requirement text, «Tu respuesta» and one action; no '
        '«Guardar borrador»', (tester) async {
      await _pump(
        tester,
        sampleRequirement(components: const [_textComponent]),
      );

      expect(find.text('Sin enviar'), findsOneWidget);
      expect(find.text('Paso 1 de 3 · Ver todos los estados'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('certification-requirement-description')),
        findsOneWidget,
      );
      expect(find.text('TU RESPUESTA'), findsOneWidget);
      expect(find.text('Enviar respuesta'), findsOneWidget);
      expect(find.text('Guardar borrador'), findsNothing);
      expect(find.text('HISTORIAL'), findsNothing);
      expect(_sendEnabled(tester), isFalse);
    });

    testWidgets(
        'typing keeps a local draft; sending saves, submits and stays on the '
        'screen turning «Enviado»', (tester) async {
      final env = await _pump(
        tester,
        sampleRequirement(components: const [_textComponent]),
      );

      await tester.enterText(
        find.byKey(const ValueKey('certification-answer-field')),
        'Reviso asistencia, reparto roles y cierro con oración.',
      );
      await tester.pumpAndSettle();

      expect(env.drafts.saved, isNotEmpty);
      expect(_sendEnabled(tester), isTrue);

      await tester.tap(find.byKey(_sendKey));
      await tester.pumpAndSettle();

      expect(env.repo.submitCalls, 1);
      expect(
        env.repo.savedDraft!.single.textValue,
        'Reviso asistencia, reparto roles y cierro con oración.',
      );
      // Same place, now «Enviado» and read-only: no action left.
      expect(find.text('Enviado'), findsOneWidget);
      expect(find.byKey(_sendKey), findsNothing);
      expect(find.byKey(const ValueKey('certification-answer-readonly')),
          findsOneWidget);
    });
  });

  testWidgets('files: the ones already uploaded count and the action sends N',
      (tester) async {
    await _pump(
      tester,
      sampleRequirement(components: const [_filesComponent]),
    );

    expect(find.text('Hasta 3 archivos'), findsOneWidget);
    expect(find.text('ARCHIVOS'), findsOneWidget);
    expect(find.byType(EvidenceStagingManager), findsOneWidget);
    final bar = tester.widget<EvidenceStagingActionBar>(
        find.byType(EvidenceStagingActionBar));
    expect(bar.fileCount, 2);
    expect(bar.canSubmit, isTrue);
    expect(bar.isResend, isFalse);
  });

  group('linked activity', () {
    testWidgets('«Elegir actividad» opens the sheet and the choice is a row',
        (tester) async {
      final env = await _pump(
        tester,
        sampleRequirement(components: const [_activityComponent]),
      );

      expect(find.text('ACTIVIDAD'), findsOneWidget);
      expect(find.text('Enviar'), findsOneWidget);
      expect(_sendEnabled(tester), isFalse);

      await tester.tap(find.text('Elegir actividad'));
      await tester.pumpAndSettle();
      expect(find.text('Elige una actividad'), findsOneWidget);
      expect(find.text('Feria de especialidades'), findsOneWidget);

      await tester.tap(find.text('Campamento de otoño'));
      await tester.pumpAndSettle();

      expect(find.text('Campamento de otoño'), findsOneWidget);
      expect(find.text('Elegir actividad'), findsNothing);
      expect(
        env.drafts.saved.values.single[3]!.linkedActivityId,
        91,
      );
      expect(_sendEnabled(tester), isTrue);
    });
  });

  testWidgets('attestation: a row with a switch enables «Enviar»',
      (tester) async {
    await _pump(
      tester,
      sampleRequirement(components: const [_attestationComponent]),
    );

    expect(find.text('CONSTANCIA'), findsOneWidget);
    expect(find.text('Confirmo que cumplí con lo solicitado'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    expect(_sendEnabled(tester), isFalse);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(_sendEnabled(tester), isTrue);
  });

  testWidgets(
      'sent back: the local field note shows once, no history, the action '
      'says «Reenviar»', (tester) async {
    await _pump(
      tester,
      sampleRequirement(
        status: CertificationRequirementStatus.changesRequested,
        components: const [_textComponent],
        comment: 'Falta la firma del director',
        reviewedAt: DateTime(2026, 3, 2),
      ),
    );

    expect(find.text('Por corregir'), findsWidgets);
    expect(find.text('«Falta la firma del director»'), findsOneWidget);
    expect(find.textContaining('Falta la firma del director'), findsOneWidget);
    expect(find.text('NOTA DEL CAMPO LOCAL'), findsOneWidget);
    expect(find.text('HISTORIAL'), findsNothing);
    expect(find.text('Reenviar'), findsOneWidget);
    // The answer is editable again.
    expect(find.byKey(const ValueKey('certification-answer-field')),
        findsOneWidget);
  });

  testWidgets('sent: read-only and no action', (tester) async {
    await _pump(
      tester,
      sampleRequirement(
        status: CertificationRequirementStatus.submitted,
        submittedAt: DateTime(2026, 3, 10),
        components: const [
          CertificationRequirementComponent(
            componentId: 1,
            type: CertificationComponentType.textResponse,
            label: 'Describe cómo planificas una reunión de club',
            required: true,
            response: CertificationComponentResponse(textValue: 'Mi respuesta'),
          ),
        ],
      ),
    );

    expect(find.text('Enviado'), findsOneWidget);
    expect(find.text('Paso 2 de 3 · Ver todos los estados'), findsOneWidget);
    expect(find.text('Mi respuesta'), findsOneWidget);
    expect(find.byKey(_sendKey), findsNothing);
    expect(find.byType(EvidenceStagingActionBar), findsNothing);
    expect(
        find.byKey(const ValueKey('certification-answer-field')), findsNothing);
  });

  testWidgets('the panel and the ⋯ menu open the sheet of every state',
      (tester) async {
    await _pump(
      tester,
      sampleRequirement(components: const [_textComponent]),
    );

    await tester.tap(find.byKey(const ValueKey('certification-status-panel')));
    await tester.pumpAndSettle();
    expect(find.text('Estados del requisito'), findsOneWidget);
    expect(find.text('Por corregir'), findsOneWidget);
    await tester.tapAt(const Offset(20, 40));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('certification-requirement-menu')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Estados del requisito'), findsOneWidget);
  });
}
