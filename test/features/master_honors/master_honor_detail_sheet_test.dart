import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_state_panel.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
import 'package:sacdia_app/features/master_honors/domain/entities/master_honor_roadmap.dart';
import 'package:sacdia_app/features/master_honors/presentation/widgets/master_honor_detail_presentation.dart';
import 'package:sacdia_app/features/master_honors/presentation/widgets/master_honor_detail_sheet.dart';

import '../../support/l10n_test_support.dart';
import '../../support/riverpod_test_support.dart';

MasterHonorRoadmapOption option(
  String label, {
  bool completed = false,
  int id = 0,
}) {
  return MasterHonorRoadmapOption(
    optionId: id == 0 ? label.hashCode : id,
    label: label,
    completed: completed,
    honorIds: const [],
    completedHonorIds: const [],
  );
}

MasterHonorRoadmapGroup requirementGroup({
  int id = 1,
  String groupType = 'CATEGORY_COUNT',
  String? title,
  String? categoryName,
  String? description,
  int minimumRequired = 7,
  int currentCount = 0,
  List<int> matchedHonorIds = const [],
  List<MasterHonorRoadmapOption> options = const [],
}) {
  return MasterHonorRoadmapGroup(
    groupId: id,
    groupType: groupType,
    title: title,
    description: description,
    minimumRequired: minimumRequired,
    currentCount: currentCount,
    passed: currentCount >= minimumRequired,
    categoryName: categoryName,
    matchedHonorIds: matchedHonorIds,
    options: options,
  );
}

MasterHonorRoadmap roadmap({
  String name = 'Maestría en Conservación',
  bool isAwarded = false,
  bool isCurrent = true,
  String? status,
  int completedGroups = 0,
  int totalGroups = 1,
  int progressPercent = 0,
  List<MasterHonorRoadmapGroup> requirementGroups = const [],
}) {
  return MasterHonorRoadmap(
    masterHonorId: 1,
    name: name,
    status: status,
    isCurrent: isCurrent,
    isAwarded: isAwarded,
    completedGroups: completedGroups,
    totalGroups: totalGroups,
    progressPercent: progressPercent,
    requirementGroups: requirementGroups,
  );
}

/// In progress: 3 of the 7 specialties of one category.
MasterHonorRoadmap conservationInProgress() => roadmap(
      progressPercent: 43,
      requirementGroups: [
        requirementGroup(
          categoryName: 'Conservación',
          currentCount: 3,
          matchedHonorIds: const [10, 11, 12],
        ),
      ],
    );

void main() {
  setUpAll(loadSpanishTranslations);

  group('humanizeMasterHonorLabel', () {
    test('should title-case a lowercase category name', () {
      expect(humanizeMasterHonorLabel('flora'), 'Flora');
    });

    test('should keep mixed-case labels', () {
      expect(humanizeMasterHonorLabel('Árboles'), 'Árboles');
    });

    test('should keep short acronyms', () {
      expect(humanizeMasterHonorLabel('ADRA'), 'ADRA');
    });
  });

  group('masterHonorRequirementLabel', () {
    test('should prefer title over category and description', () {
      expect(
        masterHonorRequirementLabel(
          requirementGroup(
            title: 'flora',
            categoryName: 'naturaleza',
            description: 'Completa 4 especialidades',
          ),
        ),
        'Flora',
      );
    });

    test('should use category when title is missing', () {
      expect(
        masterHonorRequirementLabel(requirementGroup(categoryName: 'flora')),
        'Flora',
      );
    });
  });

  group('masterHonorShowsRequirementDescription', () {
    test('should hide description when it was used as the only other copy', () {
      expect(
        masterHonorShowsRequirementDescription(
          requirementGroup(
            title: 'Completa 4 especialidades',
            description: 'Completa 4 especialidades',
          ),
        ),
        isFalse,
      );
    });

    test('should show a distinct description', () {
      expect(
        masterHonorShowsRequirementDescription(
          requirementGroup(
            title: 'flora',
            description: 'Completa 4 especialidades',
          ),
        ),
        isTrue,
      );
    });
  });

  group('MasterHonorStatusCopy', () {
    test('in progress with one open category says how many are missing', () {
      final copy = MasterHonorStatusCopy.of(conservationInProgress());

      expect(copy.title, 'En progreso');
      expect(
        copy.message,
        'Te faltan 4 especialidades de la categoría Conservación.',
      );
    });

    test('uses the singular when one specialty is missing', () {
      final copy = MasterHonorStatusCopy.of(
        roadmap(
          progressPercent: 86,
          requirementGroups: [
            requirementGroup(categoryName: 'Conservación', currentCount: 6),
          ],
        ),
      );

      expect(
        copy.message,
        'Te falta 1 especialidad de la categoría Conservación.',
      );
    });

    test('does not name a category when several requirements are open', () {
      final copy = MasterHonorStatusCopy.of(
        roadmap(
          completedGroups: 0,
          totalGroups: 2,
          progressPercent: 30,
          requirementGroups: [
            requirementGroup(categoryName: 'Conservación', currentCount: 3),
            requirementGroup(
              id: 2,
              categoryName: 'Zoología',
              currentCount: 1,
              minimumRequired: 5,
            ),
          ],
        ),
      );

      expect(
        copy.message,
        'Te faltan 8 especialidades para completar los requisitos.',
      );
    });

    test('obtained says so', () {
      final copy = MasterHonorStatusCopy.of(roadmap(isAwarded: true));

      expect(copy.title, 'Obtenida');
      expect(copy.message, 'Cumples todos los requisitos de esta maestría.');
    });

    test('no longer valid explains what is missing to recover it', () {
      final copy = MasterHonorStatusCopy.of(
        roadmap(
          isAwarded: true,
          isCurrent: false,
          status: 'REVOKED',
          requirementGroups: [
            requirementGroup(categoryName: 'Conservación', currentCount: 6),
          ],
        ),
      );

      expect(copy.title, 'No vigente');
      expect(
        copy.message,
        'Ya no cumples los requisitos actuales. '
        'Te falta 1 especialidad para recuperarla.',
      );
    });

    test('no progress says how many requirements to meet', () {
      expect(
        MasterHonorStatusCopy.of(
          roadmap(
            totalGroups: 2,
            requirementGroups: [
              requirementGroup(),
              requirementGroup(id: 2),
            ],
          ),
        ).message,
        'Cumple los 2 requisitos para obtenerla.',
      );
      expect(
        MasterHonorStatusCopy.of(roadmap()).message,
        'Cumple el requisito para obtenerla.',
      );
      expect(MasterHonorStatusCopy.of(roadmap()).title, 'Sin avance');
    });
  });

  group('MasterHonorDetailSheet', () {
    Future<void> pumpSheet(
      WidgetTester tester,
      MasterHonorRoadmap item, {
      List<Honor> honors = const [],
    }) async {
      await tester.pumpWidget(
        testProviderScope(
          overrides: [allHonorsProvider.overrideWith((ref) async => honors)],
          child: MediaQuery(
            data: const MediaQueryData(
              disableAnimations: true,
              size: Size(390, 844),
              padding: EdgeInsets.only(bottom: 34),
            ),
            child: MaterialApp(
              home: Scaffold(body: MasterHonorDetailSheet(item: item)),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('shows the full name and the status in a panel',
        (tester) async {
      await pumpSheet(tester, conservationInProgress());

      expect(find.text('Maestría en Conservación'), findsOneWidget);
      expect(find.byType(SacStatePanel), findsOneWidget);
      expect(find.text('En progreso'), findsOneWidget);
      expect(
        find.text('Te faltan 4 especialidades de la categoría Conservación.'),
        findsOneWidget,
      );
    });

    group('one requirement group', () {
      testWidgets('shows a single count, not "0 de 1 requisitos"',
          (tester) async {
        await pumpSheet(tester, conservationInProgress());

        expect(find.text('3 de 7 especialidades'), findsOneWidget);
        expect(find.textContaining('requisitos'), findsNothing);
        expect(find.textContaining('% del total'), findsNothing);
        expect(find.text('Conservación'), findsOneWidget);
        expect(find.text('REQUISITO'), findsOneWidget);
      });

      testWidgets('draws the bar in the app accent at the group fraction',
          (tester) async {
        await pumpSheet(tester, conservationInProgress());

        final bar = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        final context = tester.element(find.byType(LinearProgressIndicator));
        expect(bar.value, closeTo(3 / 7, 0.001));
        expect(bar.color, SacAccent.of(context).color);
      });

      testWidgets('lists the honors that already count by name',
          (tester) async {
        await pumpSheet(
          tester,
          conservationInProgress(),
          honors: const [
            Honor(id: 10, name: 'Árboles', categoryId: 3),
            Honor(id: 11, name: 'Ecología', categoryId: 3),
            Honor(id: 12, name: 'Flores', categoryId: 3),
            Honor(id: 13, name: 'Aves', categoryId: 3),
          ],
        );

        expect(find.text('Árboles'), findsOneWidget);
        expect(find.text('Ecología'), findsOneWidget);
        expect(find.text('Flores'), findsOneWidget);
        // Only the honors that count, not the whole category.
        expect(find.text('Aves'), findsNothing);
      });

      testWidgets('uses the singular when the group asks for one specialty',
          (tester) async {
        await pumpSheet(
          tester,
          roadmap(
            requirementGroups: [
              requirementGroup(
                categoryName: 'Conservación',
                minimumRequired: 1,
                currentCount: 0,
              ),
            ],
          ),
        );

        expect(find.text('0 de 1 especialidad'), findsOneWidget);
      });

      testWidgets('the bar uses the warning colour only when no longer valid',
          (tester) async {
        await pumpSheet(
          tester,
          roadmap(
            isAwarded: true,
            isCurrent: false,
            status: 'REVOKED',
            requirementGroups: [
              requirementGroup(categoryName: 'Conservación', currentCount: 6),
            ],
          ),
        );

        final bar = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        final context = tester.element(find.byType(LinearProgressIndicator));
        expect(bar.color, context.sac.onWarningContainer);
        expect(find.text('No vigente'), findsOneWidget);
        expect(
          find.text(
            'Ya no cumples los requisitos actuales. '
            'Te falta 1 especialidad para recuperarla.',
          ),
          findsOneWidget,
        );
      });
    });

    group('several requirement groups', () {
      MasterHonorRoadmap twoGroups() => roadmap(
            name: 'Maestría en Crecimiento Espiritual',
            totalGroups: 2,
            requirementGroups: [
              requirementGroup(
                categoryName: 'Crecimiento espiritual',
                minimumRequired: 5,
              ),
              requirementGroup(
                id: 2,
                groupType: 'EXPLICIT_OPTIONS',
                minimumRequired: 1,
                options: [
                  option('Liderazgo', id: 1),
                  option('Servicio comunitario', id: 2),
                  option('Testificación', id: 3),
                ],
              ),
            ],
          );

      testWidgets('shows the eyebrow with how many are met', (tester) async {
        await pumpSheet(tester, twoGroups());

        expect(find.text('REQUISITOS · 0 DE 2'), findsOneWidget);
        expect(find.text('REQUISITO'), findsNothing);
        expect(
          find.text('Cumple los 2 requisitos para obtenerla.'),
          findsOneWidget,
        );
      });

      testWidgets('gives each group its own row with its own count',
          (tester) async {
        await pumpSheet(tester, twoGroups());

        expect(find.text('Crecimiento espiritual'), findsOneWidget);
        expect(find.text('0 de 5 especialidades'), findsOneWidget);
        // "Choose N of M" with its options on one line.
        expect(find.text('Elige 1 de 3'), findsOneWidget);
        expect(
          find.textContaining(
            'Liderazgo · Servicio comunitario · Testificación',
            findRichText: true,
          ),
          findsOneWidget,
        );
        // No bar and no per-group chips in the compact rows.
        expect(find.byType(LinearProgressIndicator), findsNothing);
      });

      testWidgets('counts the groups that are already met', (tester) async {
        await pumpSheet(
          tester,
          roadmap(
            totalGroups: 2,
            completedGroups: 1,
            progressPercent: 50,
            requirementGroups: [
              requirementGroup(
                categoryName: 'Zoología',
                minimumRequired: 3,
                currentCount: 3,
              ),
              requirementGroup(id: 2, categoryName: 'Flora', currentCount: 2),
            ],
          ),
        );

        expect(find.text('REQUISITOS · 1 DE 2'), findsOneWidget);
        expect(find.text('3 de 3 especialidades'), findsOneWidget);
        expect(find.text('2 de 7 especialidades'), findsOneWidget);
      });
    });

    testWidgets('says so when the mastery has no requirements', (tester) async {
      await pumpSheet(tester, roadmap(totalGroups: 0));

      expect(
        find.text('Aún no hay requisitos configurados para esta maestría.'),
        findsOneWidget,
      );
    });
  });
}
