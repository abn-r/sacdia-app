import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/providers/riverpod_aliases.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_pdf_viewer.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
import 'package:sacdia_app/features/honors/presentation/theme/honor_category_palette.dart';
import 'package:sacdia_app/features/honors/presentation/views/honor_evidence_view.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_progress_band.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_segmented_tabs.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_signed_evidence_image.dart';
import 'package:sacdia_app/features/validation/domain/entities/validation.dart';
import 'package:sacdia_app/features/validation/presentation/providers/validation_providers.dart';

import '../../../certificate_import/support/test_app.dart';

class _RecordingSubmitNotifier extends SubmitValidationNotifier {
  _RecordingSubmitNotifier({this.succeeds = true});

  final bool succeeds;
  final List<({ValidationEntityType type, int id})> calls = [];

  @override
  Future<bool> submit({
    required ValidationEntityType entityType,
    required int entityId,
  }) async {
    calls.add((type: entityType, id: entityId));
    return succeeds;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initTestLocalization);

  const honor = Honor(
    id: 7,
    name: 'Arte de acampar',
    categoryId: 1,
    categoryName: 'Artes y Actividades Manuales',
    approval: 1,
    clubTypeId: 1,
    materialUrl: 'https://example.com/form.pdf',
  );
  final bandColor = bandColorFor(
    categoryId: honor.categoryId,
    categoryName: honor.categoryName,
  );
  final goodDate = DateTime(2026, 9, 30);
  const missingAll = 'Te falta: el formato completado, una evidencia general '
      'y la fecha de finalización';

  UserHonor userHonor({
    String validationStatus = 'IN_PROGRESS',
    String? document,
    List<String> images = const [],
    DateTime? completedAt,
    String? rejectionReason,
  }) {
    return UserHonor(
      id: 77,
      honorId: 7,
      userId: 'user-1',
      completionMode: HonorCompletionMode.external,
      validationStatus: validationStatus,
      document: document,
      images: images,
      completedAt: completedAt,
      rejectionReason: rejectionReason,
      date: DateTime(2026, 6, 11),
    );
  }

  late _RecordingSubmitNotifier submitNotifier;

  Future<void> pumpEvidence(
    WidgetTester tester,
    UserHonor current, {
    bool submitSucceeds = true,
  }) async {
    phoneSurface(tester, height: 3200);
    submitNotifier = _RecordingSubmitNotifier(succeeds: submitSucceeds);
    await tester.pumpWidget(
      wrapTestApp(
        const HonorEvidenceView(honorId: 7, userHonorId: 77),
        overrides: <Override>[
          allHonorsProvider.overrideWith((ref) async => [honor]),
          activeHonorCatalogClubTypeIdProvider
              .overrideWith((ref) => const AsyncValue.data(null)),
          userHonorsProvider.overrideWith((ref) async => [current]),
          submitValidationProvider.overrideWith(() => submitNotifier),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
  }

  HonorProgressBand bandOf(WidgetTester tester) =>
      tester.widget<HonorProgressBand>(find.byType(HonorProgressBand));

  List<String> tabsOf(WidgetTester tester) =>
      tester.widget<HonorSegmentedTabs>(find.byType(HonorSegmentedTabs)).labels;

  String summaryOf(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const ValueKey('honor-submit-summary')))
      .data!;

  SacButton submitButton(WidgetTester tester) => tester
      .widget<SacButton>(find.byKey(const ValueKey('honor-submit-button')));

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('band', () {
    testWidgets('new honor: working step, empty ring, external meta',
        (tester) async {
      await pumpEvidence(tester, userHonor());

      final band = bandOf(tester);
      expect(band.bandColor, bandColor);
      expect(band.step, HonorWorkStep.working);
      expect(band.progress, 0);
      expect(band.metaLabel, '0% · Fuera de la app');
      expect(band.badge, isNull);
      expect(band.honorName, 'Arte de acampar');
      expect(tabsOf(tester), ['Formato y evidencias', 'Información']);
      // The old top bar title and identity row are gone.
      expect(find.text('Formato y evidencias'), findsOneWidget);
    });

    testWidgets('the ring is the share of format, evidence and date',
        (tester) async {
      await pumpEvidence(
        tester,
        userHonor(document: 'https://example.com/completed.pdf'),
      );
      expect(bandOf(tester).progress, closeTo(1 / 3, 1e-9));
      expect(bandOf(tester).metaLabel, '33% · Fuera de la app');
    });

    testWidgets('everything ready fills the ring', (tester) async {
      await pumpEvidence(
        tester,
        userHonor(
          document: 'https://example.com/completed.pdf',
          images: const ['https://example.com/photo.jpg'],
          completedAt: goodDate,
        ),
      );
      expect(bandOf(tester).progress, 1);
      expect(bandOf(tester).metaLabel, '100% · Fuera de la app');
    });

    testWidgets('rejected: "Rechazada" badge and the reason on the first tab',
        (tester) async {
      await pumpEvidence(
        tester,
        userHonor(
          validationStatus: 'REJECTED',
          rejectionReason: 'La foto no se ve',
        ),
      );

      final badge = bandOf(tester).badge! as SacBadge;
      expect(badge.label, 'Rechazada');
      expect(bandOf(tester).step, HonorWorkStep.working);
      expect(
          find.byKey(const ValueKey('honor-rejection-card')), findsOneWidget);
      expect(find.text('La foto no se ve'), findsOneWidget);

      // The notice belongs to the first tab only.
      await tester.tap(find.byKey(const ValueKey('honor-tab-1')));
      await settle(tester);
      expect(find.byKey(const ValueKey('honor-rejection-card')), findsNothing);
      // A rejected honor can be fixed and sent again.
      expect(find.byKey(const ValueKey('honor-submit-button')), findsOneWidget);
    });

    testWidgets('under review: "En revisión" badge and the review step',
        (tester) async {
      await pumpEvidence(
        tester,
        userHonor(
          validationStatus: 'PENDING_REVIEW',
          document: 'https://example.com/completed.pdf',
          images: const ['https://example.com/photo.jpg'],
          completedAt: goodDate,
        ),
      );

      final badge = bandOf(tester).badge! as SacBadge;
      expect(badge.label, 'En revisión');
      expect(bandOf(tester).step, HonorWorkStep.inReview);
    });

    testWidgets('the abandon menu sits in the top bar while it can be left',
        (tester) async {
      await pumpEvidence(tester, userHonor());
      expect(find.byKey(const ValueKey('honor-abandon-menu')), findsOneWidget);
    });
  });

  group('"Formato y evidencias" tab', () {
    testWidgets('empty: asks for the format, no evidence, material shown',
        (tester) async {
      await pumpEvidence(tester, userHonor());

      expect(find.text('Formato completado'), findsOneWidget);
      expect(find.text('PDF ya llenado'), findsOneWidget);
      expect(find.text('Evidencias generales'), findsOneWidget);
      expect(find.text('0/10'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('external-add-evidence')), findsOneWidget);
      expect(find.text('Material de estudio'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('external-format-replace')), findsNothing);
    });

    testWidgets('with a format: replaceable, and tapping it opens the PDF',
        (tester) async {
      await pumpEvidence(
        tester,
        userHonor(
          document: 'https://example.com/completed.pdf',
          images: const ['https://example.com/photo.jpg'],
        ),
      );

      expect(
          find.text('Listo. El archivo final está cargado.'), findsOneWidget);
      expect(find.text('Reemplazar'), findsOneWidget);
      expect(find.text('1/10'), findsOneWidget);

      await tester.tap(find.text('Formato completado'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(SacPdfViewer, skipOffstage: false), findsOneWidget);
    });

    testWidgets('study material opens the in-app PDF viewer', (tester) async {
      await pumpEvidence(tester, userHonor());

      await tester.tap(find.text('Material de estudio'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(SacPdfViewer, skipOffstage: false), findsOneWidget);
    });

    testWidgets('general evidence grid sits right under its header (no gap)',
        (tester) async {
      await pumpEvidence(
        tester,
        userHonor(
          document: 'https://example.com/completed.pdf',
          images: const ['batches/b1/sealed/f1.pdf'],
        ),
      );

      final subtitleBottom =
          tester.getBottomLeft(find.text('Fotos que acompañan el formato')).dy;
      final firstTileTop = tester
          .getTopLeft(
            find
                .descendant(
                  of: find.byType(GridView),
                  matching: find.byType(GestureDetector),
                )
                .first,
          )
          .dy;

      // The header block is followed by a 12pt spacer.
      expect(firstTileTop - subtitleBottom, lessThan(24));
    });

    group('general evidence files', () {
      const signedPdf =
          'https://files.example.com/batches/b1/sealed/f1.pdf?X-Amz-Signature=abc&X-Amz-Expires=3600';

      testWidgets(
          'a presigned PDF (query after .pdf) shows a PDF tile, not an image',
          (tester) async {
        await pumpEvidence(
          tester,
          userHonor(validationStatus: 'APPROVED', images: const [signedPdf]),
        );

        expect(find.text('PDF'), findsOneWidget);
        expect(find.byType(HonorSignedEvidenceImage), findsNothing);
      });

      testWidgets('tapping a presigned PDF opens the in-app PDF viewer',
          (tester) async {
        await pumpEvidence(
          tester,
          userHonor(validationStatus: 'APPROVED', images: const [signedPdf]),
        );

        await tester.tap(find.text('PDF'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        final viewer = tester.widget<SacPdfViewer>(
          find.byType(SacPdfViewer, skipOffstage: false),
        );
        expect(viewer.pdfSource, signedPdf);
      });

      testWidgets('a photo still uses the image widget', (tester) async {
        await pumpEvidence(
          tester,
          userHonor(
            validationStatus: 'APPROVED',
            images: const ['https://files.example.com/p.jpg?X-Amz-Signature=a'],
          ),
        );

        expect(find.byType(HonorSignedEvidenceImage), findsOneWidget);
        expect(find.text('PDF'), findsNothing);
      });

      testWidgets(
          'an unsigned storage key gets a placeholder, not a broken image',
          (tester) async {
        await pumpEvidence(
          tester,
          userHonor(
            validationStatus: 'APPROVED',
            images: const ['batches/b1/sealed/f1.webp'],
          ),
        );

        expect(find.byType(HonorSignedEvidenceImage), findsNothing);
        expect(find.byType(SacPdfViewer, skipOffstage: false), findsNothing);
      });

      testWidgets('an unsigned PDF key does not open the viewer',
          (tester) async {
        await pumpEvidence(
          tester,
          userHonor(
            validationStatus: 'APPROVED',
            images: const ['batches/b1/sealed/f1.pdf'],
          ),
        );

        await tester.tap(find.text('PDF'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byType(SacPdfViewer, skipOffstage: false), findsNothing);
        expect(find.text('No pudimos abrir este archivo. Inténtalo más tarde.'),
            findsOneWidget);
      });
    });

    testWidgets('pending review hides edit actions', (tester) async {
      await pumpEvidence(
        tester,
        userHonor(
          validationStatus: 'PENDING_REVIEW',
          document: 'https://example.com/completed.pdf',
          images: const ['https://example.com/photo.jpg'],
          completedAt: goodDate,
        ),
      );

      expect(find.text('Reemplazar'), findsNothing);
      expect(find.byKey(const ValueKey('external-add-evidence')), findsNothing);
    });
  });

  group('"Información" tab', () {
    testWidgets('holds the completion date, instructor, mode and levels',
        (tester) async {
      await pumpEvidence(tester, userHonor());
      await tester.tap(find.byKey(const ValueKey('honor-tab-1')));
      await settle(tester);

      expect(find.text('Fecha de finalización'), findsOneWidget);
      expect(find.text('Instructor o instructora'), findsOneWidget);
      expect(find.text('Fuera de la app'), findsOneWidget);
      expect(find.text('General'), findsOneWidget);
      // Moved out of the first tab.
      expect(find.text('Formato completado'), findsNothing);
    });
  });

  group('sticky submit bar', () {
    testWidgets('is there from the start and says everything that is missing',
        (tester) async {
      await pumpEvidence(tester, userHonor());

      expect(summaryOf(tester), missingAll);
      expect(submitButton(tester).onPressed, isNull);
      expect(find.text('Enviar a revisión'), findsOneWidget);
    });

    testWidgets('drops the format once it is uploaded', (tester) async {
      await pumpEvidence(
        tester,
        userHonor(document: 'https://example.com/completed.pdf'),
      );
      expect(summaryOf(tester),
          'Te falta: una evidencia general y la fecha de finalización');
    });

    testWidgets('only the date is left', (tester) async {
      await pumpEvidence(
        tester,
        userHonor(
          document: 'https://example.com/completed.pdf',
          images: const ['https://example.com/photo.jpg'],
        ),
      );
      expect(summaryOf(tester), 'Te falta: la fecha de finalización');
      // The main button leads to the date picker instead of a disabled send.
      expect(find.byKey(const ValueKey('honor-submit-pick-date')), findsOne);
      expect(find.byKey(const ValueKey('honor-submit-button')), findsNothing);
    });

    testWidgets('with more missing, the date is a link and send stays off',
        (tester) async {
      await pumpEvidence(
        tester,
        userHonor(images: const ['https://example.com/photo.jpg']),
      );
      expect(submitButton(tester).onPressed, isNull);
      expect(
        find.byKey(const ValueKey('honor-submit-pick-date-link')),
        findsOne,
      );
    });

    testWidgets('ready: enabled, and sending submits the user honor id',
        (tester) async {
      await pumpEvidence(
        tester,
        userHonor(
          document: 'https://example.com/completed.pdf',
          images: const ['https://example.com/photo.jpg'],
          completedAt: goodDate,
        ),
      );

      expect(summaryOf(tester), 'Todo listo para enviar');
      expect(submitButton(tester).backgroundColor, bandColor);
      expect(submitButton(tester).onPressed, isNotNull);

      await tester.tap(find.byKey(const ValueKey('honor-submit-button')));
      await settle(tester);

      expect(
        submitNotifier.calls,
        [(type: ValidationEntityType.honor, id: 77)],
      );
    });

    testWidgets('a failed submit says so', (tester) async {
      await pumpEvidence(
        tester,
        userHonor(
          document: 'https://example.com/completed.pdf',
          images: const ['https://example.com/photo.jpg'],
          completedAt: goodDate,
        ),
        submitSucceeds: false,
      );

      await tester.tap(find.byKey(const ValueKey('honor-submit-button')));
      await settle(tester);

      expect(
          find.text('Ocurrió un error. Inténtalo de nuevo.'), findsOneWidget);
    });

    testWidgets('under review: the review notice replaces the button',
        (tester) async {
      await pumpEvidence(
        tester,
        userHonor(
          validationStatus: 'PENDING_REVIEW',
          document: 'https://example.com/completed.pdf',
          images: const ['https://example.com/photo.jpg'],
          completedAt: goodDate,
        ),
      );

      expect(find.byKey(const ValueKey('honor-submit-button')), findsNothing);
      expect(find.text('Un responsable está revisando tu trabajo'),
          findsOneWidget);
    });

    testWidgets('a validated honor has no bar', (tester) async {
      await pumpEvidence(tester, userHonor(validationStatus: 'APPROVED'));
      expect(find.byKey(const ValueKey('honor-submit-bar')), findsNothing);
    });
  });
}
