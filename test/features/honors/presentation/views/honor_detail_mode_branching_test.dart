import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor_category.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor_requirement_progress.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
import 'package:sacdia_app/features/honors/presentation/views/honor_detail_view.dart';

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

  UserHonor userHonor(HonorCompletionMode mode) {
    return UserHonor(
      id: 77,
      honorId: 7,
      userId: 'user-1',
      completionMode: mode,
      validationStatus: 'IN_PROGRESS',
      date: DateTime(2026, 6, 11),
    );
  }

  Future<void> pumpDetail(
    WidgetTester tester,
    HonorCompletionMode mode,
  ) async {
    final currentHonor = honor();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          honorCategoriesProvider.overrideWith(
            (ref) async => const <HonorCategory>[],
          ),
          allHonorsProvider.overrideWith((ref) async => [currentHonor]),
          userHonorsProvider.overrideWith((ref) async => [userHonor(mode)]),
          userHonorProgressProvider(currentHonor.id).overrideWith(
            (ref) async => const <UserHonorRequirementProgress>[],
          ),
        ],
        child: MaterialApp(
          home: HonorDetailView(
            honorId: currentHonor.id,
            initialHonor: currentHonor,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
  }

  testWidgets('undecided mode shows selector and no workflow CTA',
      (tester) async {
    await pumpDetail(tester, HonorCompletionMode.undecided);

    expect(find.text('honors.work_mode.title'), findsOneWidget);
    expect(find.text('honors.detail.select_mode_cta'), findsOneWidget);
    expect(find.text('honors.detail.continue_requirements_cta'), findsNothing);
    expect(find.text('honors.detail.external_flow_cta'), findsNothing);
  });

  testWidgets('in-app mode shows requirements CTA only', (tester) async {
    await pumpDetail(tester, HonorCompletionMode.inApp);

    expect(
        find.text('honors.detail.continue_requirements_cta'), findsOneWidget);
    expect(find.text('honors.detail.external_flow_cta'), findsNothing);
  });

  testWidgets('external mode shows external flow CTA only', (tester) async {
    await pumpDetail(tester, HonorCompletionMode.external);

    expect(find.text('honors.detail.external_flow_cta'), findsWidgets);
    expect(find.text('honors.detail.continue_requirements_cta'), findsNothing);
    expect(find.text('honors.detail.complete_requirements'), findsNothing);
  });
}
