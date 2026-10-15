import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sacdia_app/core/widgets/sac_pdf_viewer.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
import 'package:sacdia_app/features/honors/presentation/views/honor_evidence_view.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_signed_evidence_image.dart';

/// No translations on purpose: the assertions below read the raw keys. The
/// scope is only there because the date field asks for the locale.
class _NoTranslations extends AssetLoader {
  const _NoTranslations();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async => {};
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Honor honor() {
    return const Honor(
      id: 7,
      name: 'Arte de acampar',
      categoryId: 1,
      approval: 1,
      clubTypeId: 1,
      materialUrl: 'https://example.com/form.pdf',
    );
  }

  UserHonor userHonor({
    String validationStatus = 'IN_PROGRESS',
    String? document,
    List<String> images = const [],
  }) {
    return UserHonor(
      id: 77,
      honorId: 7,
      userId: 'user-1',
      completionMode: HonorCompletionMode.external,
      validationStatus: validationStatus,
      document: document,
      images: images,
      date: DateTime(2026, 6, 11),
    );
  }

  Future<void> pumpEvidence(
    WidgetTester tester,
    UserHonor currentUserHonor,
  ) async {
    final currentHonor = honor();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allHonorsProvider.overrideWith((ref) async => [currentHonor]),
          activeHonorCatalogClubTypeIdProvider.overrideWith(
            (ref) => const AsyncValue.data(null),
          ),
          userHonorsProvider.overrideWith(
            (ref) async => [currentUserHonor],
          ),
        ],
        child: EasyLocalization(
          supportedLocales: const [Locale('es')],
          path: 'assets/translations',
          assetLoader: const _NoTranslations(),
          fallbackLocale: const Locale('es'),
          startLocale: const Locale('es'),
          child: Builder(
            builder: (context) => MaterialApp(
              locale: context.locale,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              home: HonorEvidenceView(
                honorId: currentHonor.id,
                userHonorId: currentUserHonor.id,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
  }

  testWidgets('external evidence screen has no category hero or duplicate CTAs',
      (tester) async {
    await pumpEvidence(tester, userHonor());

    expect(find.byType(SliverAppBar), findsNothing);
    expect(find.text('honors.detail.external_flow_cta'), findsOneWidget);
    expect(find.text('Arte de acampar'), findsOneWidget);
    expect(find.text('honors.evidence.work_heading'), findsNothing);
    expect(find.text('honors.evidence.progress_format'), findsNothing);
    expect(find.text('honors.evidence.completed_format_title'), findsOneWidget);
    expect(find.text('honors.evidence.material_title'), findsOneWidget);
    expect(find.text('honors.evidence.upload_completed_format'), findsNothing);
    expect(find.text('honors.evidence.add_button'), findsNothing);
    expect(find.text('honors.evidence.cta_upload_format'), findsNothing);
    expect(find.text('honors.evidence.cta_send'), findsNothing);
    expect(find.text('honors.evidence.general_empty_first'), findsOneWidget);
  });

  testWidgets('submit CTA appears only when format and evidence are ready',
      (tester) async {
    await pumpEvidence(
      tester,
      userHonor(
        document: 'https://example.com/completed.pdf',
        images: const ['https://example.com/photo.jpg'],
      ),
    );

    expect(find.text('honors.evidence.cta_send'), findsOneWidget);
    expect(find.text('honors.evidence.cta_upload_format'), findsNothing);
    expect(find.text('honors.evidence.upload_completed_format'), findsNothing);
    expect(
      find.text('honors.evidence.replace_completed_format'),
      findsOneWidget,
    );
  });

  testWidgets('study material opens in-app PDF viewer', (tester) async {
    await pumpEvidence(tester, userHonor());

    await tester.tap(find.text('honors.evidence.material_title'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.byType(SacPdfViewer, skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('completed format row opens in-app PDF viewer', (tester) async {
    await pumpEvidence(
      tester,
      userHonor(
        document: 'https://example.com/completed.pdf',
        images: const ['https://example.com/photo.jpg'],
      ),
    );

    await tester.tap(find.text('honors.evidence.completed_format_title'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.byType(SacPdfViewer, skipOffstage: false),
      findsOneWidget,
    );
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

    testWidgets('an unsigned PDF key does not open the viewer', (tester) async {
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
      expect(find.text('honors.evidence.file_unavailable'), findsOneWidget);
    });
  });

  testWidgets('pending review hides edit actions and submit CTA',
      (tester) async {
    await pumpEvidence(
      tester,
      userHonor(
        validationStatus: 'PENDING_REVIEW',
        document: 'https://example.com/completed.pdf',
        images: const ['https://example.com/photo.jpg'],
      ),
    );

    expect(find.text('honors.evidence.status_sent'), findsOneWidget);
    expect(find.text('honors.evidence.cta_send'), findsNothing);
    expect(
      find.text('honors.evidence.replace_completed_format'),
      findsNothing,
    );
  });
}
