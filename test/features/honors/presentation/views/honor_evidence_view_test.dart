import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/widgets/sac_pdf_viewer.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
import 'package:sacdia_app/features/honors/presentation/views/honor_evidence_view.dart';

void main() {
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
        child: MaterialApp(
          home: HonorEvidenceView(
            honorId: currentHonor.id,
            userHonorId: currentUserHonor.id,
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
    expect(find.text('honors.evidence.upload_completed_format'), findsOneWidget);
    expect(find.text('honors.evidence.add_button'), findsOneWidget);
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

  testWidgets('completed format eye opens in-app PDF viewer', (tester) async {
    await pumpEvidence(
      tester,
      userHonor(
        document: 'https://example.com/completed.pdf',
        images: const ['https://example.com/photo.jpg'],
      ),
    );

    await tester.tap(find.byTooltip('honors.evidence.open_completed_format'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.byType(SacPdfViewer, skipOffstage: false),
      findsOneWidget,
    );
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
