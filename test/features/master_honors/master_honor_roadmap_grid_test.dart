import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/widgets/badge_grid/sac_badge_card.dart';
import 'package:sacdia_app/features/master_honors/domain/entities/master_honor_roadmap.dart';
import 'package:sacdia_app/features/master_honors/presentation/widgets/master_honor_detail_presentation.dart';
import 'package:sacdia_app/features/master_honors/presentation/widgets/master_honor_roadmap_grid.dart';

import '../../support/l10n_test_support.dart';

MasterHonorRoadmapGroup reqGroup({
  int id = 1,
  int minimumRequired = 7,
  int currentCount = 0,
  String categoryName = 'Conservación',
}) {
  return MasterHonorRoadmapGroup(
    groupId: id,
    groupType: 'CATEGORY_COUNT',
    minimumRequired: minimumRequired,
    currentCount: currentCount,
    passed: currentCount >= minimumRequired,
    categoryName: categoryName,
    matchedHonorIds: const [],
    options: const [],
  );
}

void main() {
  setUpAll(loadSpanishTranslations);

  MasterHonorRoadmap roadmap({
    int id = 1,
    String name = 'Maestría en ADRA',
    String? masterImage,
    bool isAwarded = false,
    bool isCurrent = true,
    String? status,
    String? displayStatusLabel,
    int completedGroups = 0,
    int totalGroups = 5,
    int progressPercent = 0,
    List<MasterHonorRoadmapGroup> groups = const [],
  }) {
    return MasterHonorRoadmap(
      masterHonorId: id,
      name: name,
      masterImage: masterImage,
      status: status,
      isCurrent: isCurrent,
      isAwarded: isAwarded,
      displayStatusLabel: displayStatusLabel,
      completedGroups: completedGroups,
      totalGroups: totalGroups,
      progressPercent: progressPercent,
      requirementGroups: groups,
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

  group('masterHonorShortName', () {
    test('strips the Spanish prefix and keeps the rest of the name', () {
      expect(masterHonorShortName('Maestría en Conservación'), 'Conservación');
      expect(masterHonorShortName('Maestría en ADRA'), 'ADRA');
      expect(
        masterHonorShortName('Maestría en Actividades Agrícolas'),
        'Actividades Agrícolas',
      );
      expect(masterHonorShortName('Maestria de Zoología'), 'Zoología');
    });

    test('strips the prefix in English, French and Portuguese', () {
      expect(masterHonorShortName('Master in Conservation'), 'Conservation');
      expect(masterHonorShortName("Master's in Zoology"), 'Zoology');
      expect(masterHonorShortName("Maîtrise d'Écologie"), 'Écologie');
      expect(masterHonorShortName('Maîtrise en Zoologie'), 'Zoologie');
      expect(masterHonorShortName('Maestria em Aquática'), 'Aquática');
    });

    test('does not eat a word that merely starts like a preposition', () {
      expect(masterHonorShortName('Maestría en Entomología'), 'Entomología');
      expect(
          masterHonorShortName('Maestría Entomología'), 'Maestría Entomología');
    });

    test('capitalizes the first letter that is left', () {
      expect(masterHonorShortName('Maestría en conservación'), 'Conservación');
    });

    test('leaves names without the prefix alone', () {
      expect(masterHonorShortName('Conservación'), 'Conservación');
      expect(masterHonorShortName('Maestría'), 'Maestría');
      expect(masterHonorShortName('  Maestría en  '), 'Maestría en');
    });
  });

  group('masterHonorProgressCount', () {
    test('adds the specialties of every group, capped at what is required', () {
      final item = roadmap(
        groups: [
          reqGroup(currentCount: 3, minimumRequired: 7),
          reqGroup(id: 2, currentCount: 9, minimumRequired: 2),
        ],
      );

      final count = masterHonorProgressCount(item);
      expect(count.current, 5);
      expect(count.total, 9);
    });

    test('falls back to the group totals when there are no groups', () {
      final count = masterHonorProgressCount(
        roadmap(completedGroups: 2, totalGroups: 5),
      );
      expect(count.current, 2);
      expect(count.total, 5);
    });
  });

  group('MasterHonorRoadmapGrid', () {
    Future<void> pumpGrid(
      WidgetTester tester,
      List<MasterHonorRoadmap> items, {
      double textScale = 1,
      bool reduceMotion = true,
    }) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            disableAnimations: reduceMotion,
            textScaler: TextScaler.linear(textScale),
          ),
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

    final greyFilters = find.descendant(
      of: find.byType(MasterHonorRoadmapGrid),
      matching: find.byType(ColorFiltered),
    );

    testWidgets('should show the name without the Maestría en prefix',
        (tester) async {
      await pumpGrid(tester, [
        roadmap(name: 'Maestría en Conservación'),
        roadmap(id: 2, name: 'Maestría en Zoología'),
      ]);

      expect(find.text('Conservación'), findsOneWidget);
      expect(find.text('Zoología'), findsOneWidget);
      expect(find.textContaining('Maestría en'), findsNothing);
    });

    testWidgets('in progress: dimmed patch, accent bar and "3 de 7"',
        (tester) async {
      await pumpGrid(tester, [
        roadmap(
          name: 'Maestría en Conservación',
          completedGroups: 0,
          totalGroups: 1,
          progressPercent: 43,
          groups: [reqGroup(currentCount: 3)],
        ),
      ]);

      expect(find.text('3 de 7'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, closeTo(3 / 7, 0.001));
      // Dimmed, not greyed: the patch keeps its colours.
      expect(greyFilters, findsNothing);
      final opacity = tester.widget<Opacity>(
        find.ancestor(
          of: find.byType(MasterHonorLogo),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, closeTo(0.62, 0.001));
    });

    testWidgets('falls back to the group totals when there are no groups',
        (tester) async {
      await pumpGrid(tester, [
        roadmap(completedGroups: 2, totalGroups: 5, progressPercent: 40),
      ]);

      expect(find.text('2 de 5'), findsOneWidget);
      expect(find.text('0 de 5'), findsNothing);
    });

    testWidgets('no progress: grey patch and no meta', (tester) async {
      await pumpGrid(tester, [roadmap(name: 'Maestría en Acuática')]);

      expect(find.text('Acuática'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.textContaining(' de '), findsNothing);
      expect(greyFilters, findsOneWidget);
    });

    testWidgets('obtained: colour patch, "Obtenida" and no bar',
        (tester) async {
      await pumpGrid(tester, [
        roadmap(
          isAwarded: true,
          completedGroups: 5,
          totalGroups: 5,
          progressPercent: 100,
        ),
      ]);

      expect(find.text('Obtenida'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('5/5'), findsNothing);
      expect(greyFilters, findsNothing);
      expect(
        find.ancestor(
          of: find.byType(MasterHonorLogo),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
    });

    testWidgets('no longer valid: colour patch and "No vigente" text',
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
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(greyFilters, findsNothing);
    });

    testWidgets('the patch keeps its oval: only the height is decoded',
        (tester) async {
      await pumpGrid(tester, [
        roadmap(masterImage: 'https://example.com/patch.png'),
      ]);

      final image = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(image.memCacheWidth, isNull);
      expect(image.memCacheHeight, 216);
      expect(image.fit, BoxFit.contain);
    });

    testWidgets('long names fit at text scale 1.3 with equal-height cards',
        (tester) async {
      await pumpGrid(
        tester,
        [
          roadmap(
            name: 'Maestría en Crecimiento Espiritual y Ministerio Juvenil',
            completedGroups: 1,
            totalGroups: 2,
            progressPercent: 50,
          ),
          roadmap(id: 2, name: 'Maestría en ADRA'),
          roadmap(id: 3, name: 'Maestría en Deportes', isAwarded: true),
        ],
        textScale: 1.3,
      );

      expect(tester.takeException(), isNull);
      final heights = {
        for (final card in tester.widgetList(find.byType(SacBadgeCard)))
          tester.getSize(find.byWidget(card)).height,
      };
      expect(heights, hasLength(1));
    });

    testWidgets(
        'a mastery that becomes obtained animates in place, without moving',
        (tester) async {
      final inProgress = roadmap(
        name: 'Maestría en Conservación',
        completedGroups: 0,
        totalGroups: 1,
        progressPercent: 86,
        groups: [reqGroup(currentCount: 6)],
      );
      final obtained = roadmap(
        name: 'Maestría en Conservación',
        isAwarded: true,
        completedGroups: 1,
        totalGroups: 1,
        progressPercent: 100,
        groups: [reqGroup(currentCount: 7)],
      );

      await pumpGrid(tester, [inProgress], reduceMotion: false);
      // The entrance starts on a timer, then needs its own frames to finish.
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      final before = tester.getTopLeft(find.byType(SacBadgeCard));
      expect(find.text('6 de 7'), findsOneWidget);

      await pumpGrid(tester, [obtained], reduceMotion: false);
      await tester.pump(const Duration(milliseconds: 100));

      final halo = find.byWidgetPredicate((widget) =>
          widget is DecoratedBox &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).shape == BoxShape.circle &&
          ((widget.decoration as BoxDecoration).boxShadow?.isNotEmpty ??
              false));
      expect(halo, findsOneWidget);
      expect(find.text('Obtenida'), findsOneWidget);
      expect(tester.getTopLeft(find.byType(SacBadgeCard)), before);

      await tester.pump(const Duration(seconds: 2));
      expect(halo, findsNothing);
      expect(find.text('6 de 7'), findsNothing);
    });
  });
}
