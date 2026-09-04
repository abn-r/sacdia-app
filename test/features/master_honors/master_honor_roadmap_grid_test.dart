import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/master_honors/domain/entities/master_honor_roadmap.dart';
import 'package:sacdia_app/features/master_honors/presentation/widgets/master_honor_roadmap_grid.dart';

void main() {
  MasterHonorRoadmap roadmap({
    String name = 'Maestría en ADRA',
    bool isAwarded = false,
    bool isCurrent = true,
    String? status,
    String? displayStatusLabel,
    int completedGroups = 0,
    int totalGroups = 5,
    int progressPercent = 0,
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
      requirementGroups: const [],
    );
  }

  group('masterHonorGridVisual', () {
    test('should map awarded current items as awarded', () {
      expect(
        masterHonorGridVisual(roadmap(isAwarded: true)),
        MasterHonorGridVisual.awarded,
      );
    });

    test('should map revoked or non-current awarded items as inactive', () {
      expect(
        masterHonorGridVisual(
          roadmap(isAwarded: true, isCurrent: false, status: 'REVOKED'),
        ),
        MasterHonorGridVisual.inactive,
      );
    });

    test('should map partial progress as in progress', () {
      expect(
        masterHonorGridVisual(
          roadmap(completedGroups: 2, progressPercent: 40),
        ),
        MasterHonorGridVisual.inProgress,
      );
    });

    test('should map zero progress as locked', () {
      expect(
        masterHonorGridVisual(roadmap()),
        MasterHonorGridVisual.locked,
      );
    });
  });

  group('MasterHonorRoadmapGrid', () {
    Future<void> pumpGrid(
      WidgetTester tester,
      List<MasterHonorRoadmap> items,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 390,
                height: 800,
                child: MasterHonorRoadmapGrid(items: items),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('should show group progress for in-progress masteries',
        (tester) async {
      await pumpGrid(tester, [
        roadmap(completedGroups: 2, totalGroups: 5, progressPercent: 40),
      ]);

      expect(find.text('2/5'), findsOneWidget);
      expect(find.text('0/5'), findsNothing);
    });

    testWidgets('should hide empty progress on locked masteries',
        (tester) async {
      await pumpGrid(tester, [roadmap(name: 'Maestría en Acuática')]);

      expect(find.text('Maestría en Acuática'), findsOneWidget);
      expect(find.text('0/5'), findsNothing);
    });

    testWidgets('should show completed count on awarded masteries',
        (tester) async {
      await pumpGrid(tester, [
        roadmap(
          isAwarded: true,
          completedGroups: 5,
          totalGroups: 5,
          progressPercent: 100,
        ),
      ]);

      expect(find.text('5/5'), findsOneWidget);
    });

    testWidgets('should show No vigente caption on inactive masteries',
        (tester) async {
      await pumpGrid(tester, [
        roadmap(
          isAwarded: true,
          isCurrent: false,
          status: 'REVOKED',
          displayStatusLabel: 'No vigente',
          completedGroups: 5,
          totalGroups: 5,
          progressPercent: 100,
        ),
      ]);

      expect(find.text('No vigente'), findsOneWidget);
      expect(find.text('5/5'), findsNothing);
    });
  });
}
