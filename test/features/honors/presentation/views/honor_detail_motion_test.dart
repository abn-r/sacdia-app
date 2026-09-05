import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor_category.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor_requirement.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor_requirement_progress.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
import 'package:sacdia_app/features/honors/presentation/views/honor_detail_view.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_badge_image.dart';

void main() {
  testWidgets(
    'real honor detail hero enters from the shared scale without overshoot',
    (tester) async {
      final reduceMotion = ValueNotifier<bool>(false);
      addTearDown(reduceMotion.dispose);

      await _pumpDetail(tester, reduceMotion);

      expect(_heroScale(tester).scale.value, SacMotion.enterScale);
      expect(tester.binding.hasScheduledFrame, isTrue);

      for (var elapsed = 0;
          elapsed < SacMotion.routeEnter.inMilliseconds;
          elapsed += 40) {
        await tester.pump(const Duration(milliseconds: 40));
        expect(_heroScale(tester).scale.value, greaterThanOrEqualTo(0.96));
        expect(_heroScale(tester).scale.value, lessThanOrEqualTo(1));
      }

      expect(_heroScale(tester).scale.value, 1);
    },
  );

  testWidgets('real honor detail is settled without frames when reduced', (
    tester,
  ) async {
    final reduceMotion = ValueNotifier<bool>(true);
    addTearDown(reduceMotion.dispose);

    await _pumpDetail(tester, reduceMotion);

    expect(_heroScale(tester).scale.value, 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets(
    'real honor detail settles for reduced motion without replaying its hero',
    (tester) async {
      final reduceMotion = ValueNotifier<bool>(false);
      addTearDown(reduceMotion.dispose);

      await _pumpDetail(tester, reduceMotion);
      await tester.pump(const Duration(milliseconds: 40));
      expect(_heroScale(tester).scale.value, inExclusiveRange(0.96, 1));

      reduceMotion.value = true;
      await tester.pump();

      expect(_heroScale(tester).scale.value, 1);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);

      reduceMotion.value = false;
      await tester.pump();

      expect(_heroScale(tester).scale.value, 1);
      expect(tester.binding.hasScheduledFrame, isFalse);
    },
  );
}

Future<void> _pumpDetail(
  WidgetTester tester,
  ValueListenable<bool> reduceMotion,
) async {
  const honor = Honor(
    id: 7,
    name: 'Arte de acampar',
    categoryId: 1,
    approval: 1,
    clubTypeId: 1,
  );
  final userHonor = UserHonor(
    id: 77,
    honorId: honor.id,
    userId: 'user-1',
    completionMode: HonorCompletionMode.inApp,
    validationStatus: 'IN_PROGRESS',
    date: DateTime(2026, 6, 11),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        honorCategoriesProvider.overrideWith(
          (ref) async => const <HonorCategory>[],
        ),
        allHonorsProvider.overrideWith((ref) async => [honor]),
        activeHonorCatalogClubTypeIdProvider.overrideWith(
          (ref) => const AsyncValue.data(null),
        ),
        userHonorsProvider.overrideWith((ref) async => [userHonor]),
        honorRequirementsProvider(honor.id).overrideWith(
          (ref) async => const <HonorRequirement>[],
        ),
        userHonorProgressProvider(honor.id).overrideWith(
          (ref) async => [
            const UserHonorRequirementProgress(
              requirementId: 1,
              requirementNumber: 1,
              text: 'Completado',
              completed: true,
            ),
            const UserHonorRequirementProgress(
              requirementId: 2,
              requirementNumber: 2,
              text: 'Pendiente',
              completed: false,
            ),
          ],
        ),
      ],
      child: ValueListenableBuilder<bool>(
        valueListenable: reduceMotion,
        child: MaterialApp(
          home: HonorDetailView(honorId: honor.id, initialHonor: honor),
        ),
        builder: (context, disabled, child) => MediaQuery(
          data: MediaQueryData(disableAnimations: disabled),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

ScaleTransition _heroScale(WidgetTester tester) =>
    tester.widget<ScaleTransition>(
      find.ancestor(
        of: find.byType(HonorBadgeImage),
        matching: find.byType(ScaleTransition),
      ),
    );
