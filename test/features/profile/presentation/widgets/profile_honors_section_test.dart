import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
import 'package:sacdia_app/features/master_honors/presentation/providers/master_honors_providers.dart';
import 'package:sacdia_app/features/profile/presentation/widgets/profile_honors_section.dart';

void main() {
  group('ProfileHonorsSection', () {
    UserHonor honor({
      required String name,
      required String validationStatus,
      String? document,
      List<String> images = const [],
    }) {
      return UserHonor(
        id: name.hashCode,
        honorId: name.hashCode,
        userId: 'user-1',
        honorName: name,
        honorCategoryName: 'ADRA',
        honorCategoryId: 1,
        validationStatus: validationStatus,
        document: document,
        images: images,
        date: DateTime(2026, 6, 11),
      );
    }

    Future<void> pumpSection(
      WidgetTester tester,
      List<UserHonor> honors,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userHonorsProvider.overrideWith((ref) async => honors),
            activeHonorCatalogClubTypeIdProvider.overrideWith(
              (ref) => const AsyncValue.data(null),
            ),
            userMasterHonorsProvider.overrideWith((ref) async => const []),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ProfileHonorsSection(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('should show a compact pastel status caption under each honor',
        (tester) async {
      await pumpSection(tester, [
        honor(name: 'Alfabetización', validationStatus: 'IN_PROGRESS'),
        honor(
          name: 'Agricultura',
          validationStatus: 'IN_PROGRESS',
          document: 'https://example.com/format.pdf',
        ),
        honor(name: 'Ayuda', validationStatus: 'PENDING_REVIEW'),
        honor(name: 'Empapelado', validationStatus: 'APPROVED'),
        honor(name: 'Perros', validationStatus: 'REJECTED'),
      ]);

      expect(find.text('profile.honors_section.status_enrolled'), findsOneWidget);
      expect(
        find.text('profile.honors_section.status_in_progress'),
        findsOneWidget,
      );
      expect(
        find.text('profile.honors_section.status_submitted'),
        findsOneWidget,
      );
      expect(
        find.text('profile.honors_section.status_validated'),
        findsOneWidget,
      );
      expect(
        find.text('profile.honors_section.status_rejected'),
        findsOneWidget,
      );
    });
  });
}
