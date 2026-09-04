import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/master_honors/domain/entities/master_honor_roadmap.dart';
import 'package:sacdia_app/features/master_honors/presentation/widgets/master_honor_detail_presentation.dart';
import 'package:sacdia_app/features/master_honors/presentation/widgets/master_honor_detail_sheet.dart';

MasterHonorRoadmapOption option(String label, {bool completed = false}) {
  return MasterHonorRoadmapOption(
    optionId: label.hashCode,
    label: label,
    completed: completed,
    honorIds: const [],
    completedHonorIds: const [],
  );
}

MasterHonorRoadmapGroup requirementGroup({
  String groupType = 'HONOR_OPTIONS',
  String? title,
  String? categoryName,
  String? description,
  int minimumRequired = 4,
  int currentCount = 0,
  bool passed = false,
  List<MasterHonorRoadmapOption> options = const [],
}) {
  return MasterHonorRoadmapGroup(
    groupId: 1,
    groupType: groupType,
    title: title,
    description: description,
    minimumRequired: minimumRequired,
    currentCount: currentCount,
    passed: passed,
    categoryName: categoryName,
    matchedHonorIds: const [],
    options: options,
  );
}

MasterHonorRoadmap roadmap({
  String name = 'Maestría en Ciencias Naturales',
  bool isAwarded = false,
  bool isCurrent = true,
  String? status,
  String? displayStatusLabel,
  int completedGroups = 1,
  int totalGroups = 3,
  int progressPercent = 14,
  List<MasterHonorRoadmapGroup> requirementGroups = const [],
}) {
  return MasterHonorRoadmap(
    masterHonorId: 1,
    name: name,
    status: status,
    isCurrent: isCurrent,
    isAwarded: isAwarded,
    displayStatusLabel: displayStatusLabel,
    completedGroups: completedGroups,
    totalGroups: totalGroups,
    progressPercent: progressPercent,
    requirementGroups: requirementGroups,
  );
}

void main() {
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

  group('MasterHonorDetailStatus', () {
    test('should label zero progress as Sin avance', () {
      expect(
        MasterHonorDetailStatus.of(
          roadmap(completedGroups: 0, totalGroups: 3, progressPercent: 0),
        ).label,
        'Sin avance',
      );
    });

    test('should label partial progress as En progreso', () {
      expect(MasterHonorDetailStatus.of(roadmap()).label, 'En progreso');
    });

    test('should label revoked awarded items as No vigente', () {
      expect(
        MasterHonorDetailStatus.of(
          roadmap(
            isAwarded: true,
            isCurrent: false,
            status: 'REVOKED',
            displayStatusLabel: 'No vigente',
          ),
        ).label,
        'No vigente',
      );
    });
  });

  group('masterHonorShowsPercentCaption', () {
    test('should show percent when it disagrees with group ratio', () {
      expect(masterHonorShowsPercentCaption(roadmap()), isTrue);
    });

    test('should hide percent when it matches completed groups', () {
      expect(
        masterHonorShowsPercentCaption(
          roadmap(completedGroups: 1, totalGroups: 3, progressPercent: 33),
        ),
        isFalse,
      );
    });
  });

  group('MasterHonorDetailSheet', () {
    Future<void> pumpSheet(
      WidgetTester tester,
      MasterHonorRoadmap item,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            disableAnimations: true,
            size: Size(390, 844),
            padding: EdgeInsets.only(bottom: 34),
          ),
          child: MaterialApp(
            home: Scaffold(
              body: MasterHonorDetailSheet(item: item),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('should show group progress instead of mixing it with percent',
        (tester) async {
      await pumpSheet(tester, roadmap());

      expect(find.text('En progreso'), findsOneWidget);
      expect(find.text('1 de 3 requisitos'), findsOneWidget);
      expect(find.text('14% del total'), findsOneWidget);
      expect(find.textContaining('requisitos completados'), findsNothing);
    });

    testWidgets('should not call locked masteries En progreso', (tester) async {
      await pumpSheet(
        tester,
        roadmap(completedGroups: 0, totalGroups: 3, progressPercent: 0),
      );

      expect(find.text('Sin avance'), findsOneWidget);
      expect(find.text('En progreso'), findsNothing);
    });

    testWidgets('should humanize requirement titles and collapse options',
        (tester) async {
      await pumpSheet(
        tester,
        roadmap(
          requirementGroups: [
            requirementGroup(
              categoryName: 'flora',
              currentCount: 0,
              minimumRequired: 4,
              options: [
                option('Árboles'),
                option('Arbustos'),
                option('Cactus, y/o avanzado'),
                option('Cataratas'),
                option('Climatología'),
                option('Hongos'),
              ],
            ),
          ],
        ),
      );

      expect(find.text('Flora'), findsOneWidget);
      expect(find.text('0/4 opciones'), findsOneWidget);
      expect(find.text('Elige 4 de 6 opciones'), findsOneWidget);
      expect(find.text('Árboles'), findsNothing);

      await tester.tap(find.text('Elige 4 de 6 opciones'));
      await tester.pump();

      expect(find.text('Árboles'), findsOneWidget);
      expect(find.text('Hongos'), findsOneWidget);
      expect(find.text('Ocultar'), findsOneWidget);
    });

    testWidgets('should show completed options before collapsing the rest',
        (tester) async {
      await pumpSheet(
        tester,
        roadmap(
          requirementGroups: [
            requirementGroup(
              categoryName: 'flora',
              currentCount: 1,
              minimumRequired: 4,
              options: [
                option('Árboles', completed: true),
                option('Arbustos'),
                option('Cactus, y/o avanzado'),
                option('Cataratas'),
                option('Hongos'),
              ],
            ),
          ],
        ),
      );

      expect(find.text('Árboles'), findsOneWidget);
      expect(find.text('Ver 4 restantes'), findsOneWidget);
      expect(find.text('Hongos'), findsNothing);
    });
  });
}
