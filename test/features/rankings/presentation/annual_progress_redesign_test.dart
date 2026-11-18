import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/rankings/domain/entities/annual_ranking_progress.dart';
import 'package:sacdia_app/features/rankings/presentation/screens/club_rankings_screen.dart';
import 'package:sacdia_app/features/rankings/presentation/utils/annual_progress_math.dart';

import '../../../support/l10n_test_support.dart';

const _bronze = RankingTier(
  name: 'Bronce',
  slug: 'bronce',
  fromPoints: 5000,
  toPoints: 6999,
  pointsToReach: 3561,
);

const _silver = RankingTier(
  name: 'Plata',
  slug: 'plata',
  fromPoints: 7000,
  toPoints: 8499,
  pointsToReach: 1000,
);

const _folder = RankingComponentProgress(
  key: 'annual_evidence_folder',
  label: 'Carpeta anual de evidencias',
  earnedPoints: 0,
  maxPoints: 3000,
  progressPercentage: 0,
);

const _finance = RankingComponentProgress(
  key: 'finance_compliance',
  label: 'Finanzas',
  earnedPoints: 333,
  maxPoints: 2000,
  progressPercentage: 16.65,
);

const _camporee = RankingComponentProgress(
  key: 'camporee_events',
  label: 'Camporee',
  earnedPoints: 165,
  maxPoints: 2000,
  progressPercentage: 8.25,
);

const _usage = RankingComponentProgress(
  key: 'sacdia_operational_usage',
  label: 'Uso operativo de SACDIA',
  earnedPoints: 941,
  maxPoints: 1000,
  progressPercentage: 94.1,
);

const _empty = RankingComponentProgress(
  key: 'activities_registered',
  label: 'Componente sin puntos',
  earnedPoints: 0,
  maxPoints: 0,
  progressPercentage: 0,
);

AnnualRankingProgress _progress({
  int currentPoints = 1439,
  RankingTier? currentTier,
  RankingTier? nextTier = _bronze,
  RankingComponentProgress folder = _folder,
  List<RankingPendingItem>? pending,
}) {
  return AnnualRankingProgress(
    sectionId: 1,
    clubId: 1,
    clubName: 'Club Orión',
    clubType: const RankingClubType(clubTypeId: 1, name: 'Conquistadores'),
    year: const RankingYear(ecclesiasticalYearId: 1),
    currentPoints: currentPoints,
    maxPoints: 10000,
    progressPercentage: currentPoints / 100,
    currentTier: currentTier,
    nextTier: nextTier,
    axes: [
      RankingAxisProgress(
        key: 'administrative',
        label: 'Administrativo',
        earnedPoints: 333,
        maxPoints: 5000,
        progressPercentage: 6.7,
        components: [folder, _finance],
      ),
      const RankingAxisProgress(
        key: 'operational',
        label: 'Operativo',
        earnedPoints: 1106,
        maxPoints: 5000,
        progressPercentage: 22,
        components: [_camporee, _empty, _usage],
      ),
    ],
    components: const [],
    pendingItems: pending ??
        [
          RankingPendingItem(
            type: 'annual_folder_section',
            title: 'Salidas recreativas',
            status: 'pending_delivery',
            statusLabelKey:
                'rankings.annual_progress.pending.status.pending_delivery',
            dueDate: DateTime(2020, 11, 15),
            actionLabel: 'Ver evidencia',
          ),
          RankingPendingItem(
            type: 'annual_folder_section',
            title: 'Servicio a la comunidad',
            status: 'pending_delivery',
            statusLabelKey:
                'rankings.annual_progress.pending.status.pending_delivery',
            dueDate: DateTime(2999, 11, 22),
            actionLabel: 'Ver evidencia',
          ),
          const RankingPendingItem(
            type: 'annual_folder_section',
            title: 'Apartado 2',
            status: 'pending_validation',
            statusLabelKey:
                'rankings.annual_progress.pending.status.pending_validation',
            dueDate: null,
            actionLabel: 'Ver evidencia',
          ),
        ],
  );
}

Future<void> _pump(
  WidgetTester tester,
  AnnualRankingProgress progress, {
  VoidCallback? onOpenFolder,
  bool canOpenFolder = true,
  bool disableAnimations = false,
  bool settle = true,
  double width = 800,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 4200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 4200),
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: Scaffold(
          body: AnnualRankingProgressContent(
            progress: progress,
            yearName: '2026',
            onRefresh: () async {},
            onOpenFolder: onOpenFolder ?? () {},
            canOpenFolder: canOpenFolder,
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

double _fillFactor(WidgetTester tester) {
  final clip = find.byKey(const ValueKey('annual-medal-fill'));
  final align = tester.widget<Align>(
    find.descendant(of: clip, matching: find.byType(Align)).first,
  );
  return align.heightFactor!;
}

void main() {
  setUpAll(loadSpanishTranslations);

  group('Annual progress math', () {
    test('medal fill is current / next threshold, clamped', () {
      expect(medalFillFraction(_progress()), closeTo(1439 / 5000, 1e-9));
      expect(
        medalFillFraction(_progress(currentPoints: 9000)),
        1,
      );
      expect(medalFillFraction(_progress(currentPoints: 0)), 0);
      expect(medalFillFraction(_progress(nextTier: null)), 1);
    });

    test('numbers use the app locale grouping', () {
      expect(formatAnnualPoints(1439, const Locale('es')), '1,439');
      expect(formatAnnualPoints(10000, const Locale('es')), '10,000');
      expect(formatAnnualPoints(1439, const Locale('en')), '1,439');
      expect(formatAnnualPoints(1439, const Locale('fr')).contains('.'), false);
    });

    test('block heights are proportional to maxPoints', () {
      final h = allocateBlockHeights(
        [3000, 2000],
        totalHeight: 380,
        gap: 8,
        minHeight: 60,
      );
      expect(h[0] / h[1], closeTo(1.5, 1e-9));
      expect(h[0] + h[1] + 8, closeTo(380, 1e-9));
    });

    test('small blocks keep the minimum height and the total holds', () {
      final h = allocateBlockHeights(
        [3000, 100, 3000],
        totalHeight: 380,
        gap: 8,
        minHeight: 60,
      );
      expect(h[1], 60);
      expect(h.reduce((a, b) => a + b) + 16, closeTo(380, 1e-9));
    });

    test('largest remaining gap wins; none when everything is earned', () {
      expect(
        componentWithLargestGap([_finance, _folder, _camporee])?.key,
        'annual_evidence_folder',
      );
      expect(
        componentWithLargestGap([
          const RankingComponentProgress(
            key: 'x',
            label: 'x',
            earnedPoints: 10,
            maxPoints: 10,
            progressPercentage: 100,
          ),
        ]),
        isNull,
      );
    });

    test('projection = current + (folder max - folder earned)', () {
      final p = annualProjection(_progress())!;
      expect(p.projectedPoints, 4439);
      expect(p.gain, 3000);
      expect(p.reachesNextTier, false);
      expect(p.missingAfter, 561);
    });

    test('projection reaches the next tier when it clears the threshold', () {
      final p = annualProjection(_progress(currentPoints: 3000))!;
      expect(p.projectedPoints, 6000);
      expect(p.reachesNextTier, true);
      expect(p.missingAfter, isNull);
    });

    test('folder alias key and a full folder', () {
      const aliased = RankingComponentProgress(
        key: 'annual_folder',
        label: 'Carpeta',
        earnedPoints: 1000,
        maxPoints: 4000,
        progressPercentage: 25,
      );
      expect(
        annualProjection(_progress(folder: aliased))!.projectedPoints,
        1439 + 3000,
      );
      const full = RankingComponentProgress(
        key: 'annual_evidence_folder',
        label: 'Carpeta',
        earnedPoints: 3000,
        maxPoints: 3000,
        progressPercentage: 100,
      );
      expect(annualProjection(_progress(folder: full)), isNull);
    });
  });

  group('Hero', () {
    testWidgets('fills the next medal to current / threshold with semantics',
        (tester) async {
      await _pump(tester, _progress());

      expect(_fillFactor(tester), closeTo(1439 / 5000, 1e-6));
      expect(
        find.bySemanticsLabel('Medalla Bronce, 29 por ciento'),
        findsOneWidget,
      );
      expect(find.text('SIGUIENTE MEDALLA'), findsOneWidget);
      expect(find.text('Te faltan 3,561 pts para alcanzarla'), findsOneWidget);
    });

    testWidgets('animates on first show and jumps under reduce motion',
        (tester) async {
      await _pump(tester, _progress(), settle: false);
      expect(_fillFactor(tester), lessThan(0.05));
      await tester.pumpAndSettle();
      expect(_fillFactor(tester), closeTo(1439 / 5000, 1e-6));

      await _pump(
        tester,
        _progress(currentPoints: 2500),
        disableAnimations: true,
        settle: false,
      );
      expect(_fillFactor(tester), closeTo(0.5, 1e-6));
    });

    testWidgets('year summary shows points of the year and no medal yet',
        (tester) async {
      await _pump(tester, _progress());

      expect(find.text('ESTE AÑO'), findsOneWidget);
      expect(find.text('1,439 de 10,000'), findsOneWidget);
      expect(find.text('Sin medalla aún'), findsOneWidget);
      expect(find.textContaining('1.439'), findsNothing);
      expect(find.textContaining('10.000'), findsNothing);
    });

    testWidgets('top tier: full color medal and a congratulation line',
        (tester) async {
      await _pump(
        tester,
        _progress(currentPoints: 9700, currentTier: _silver, nextTier: null),
      );

      expect(_fillFactor(tester), 1);
      expect(find.text('MEDALLA ACTUAL'), findsOneWidget);
      expect(find.textContaining('Felicidades'), findsOneWidget);
      expect(find.text('Plata'), findsWidgets);
    });

    testWidgets('no tiers configured: no medal, points still shown',
        (tester) async {
      await _pump(tester, _progress(nextTier: null));
      // Top-tier case above has a current tier; here none at all.
      expect(find.byKey(const ValueKey('annual-medal-fill')), findsNothing);
      expect(find.byKey(const ValueKey('annual-tiers-button')), findsNothing);
      expect(find.text('1,439 de 10,000'), findsOneWidget);
    });
  });

  group('Layout', () {
    testWidgets('fits a 360dp phone with large text without overflow',
        (tester) async {
      await _pump(tester, _progress(), width: 360, textScale: 1.4);

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('annual-open-folder')), findsOneWidget);
    });
  });

  group('Tiers sheet', () {
    testWidgets('lists the tiers with threshold and state', (tester) async {
      await _pump(
        tester,
        _progress(currentPoints: 5400, currentTier: _bronze, nextTier: _silver),
      );

      await tester.tap(find.byKey(const ValueKey('annual-tiers-button')));
      await tester.pumpAndSettle();

      expect(find.text('Rangos del año'), findsOneWidget);
      expect(find.text('Desde 5,000 pts'), findsOneWidget);
      expect(find.text('Desde 7,000 pts'), findsOneWidget);
      expect(find.text('Actual'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Bronce, Desde 5,000 pts, Actual'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Plata, Desde 7,000 pts'),
        findsOneWidget,
      );
    });
  });

  group('Block map', () {
    testWidgets('block heights are proportional inside a column',
        (tester) async {
      await _pump(tester, _progress());

      final folder = tester
          .getSize(
              find.byKey(const ValueKey('annual-block-annual_evidence_folder')))
          .height;
      final finance = tester
          .getSize(
              find.byKey(const ValueKey('annual-block-finance_compliance')))
          .height;
      expect(folder / finance, closeTo(1.5, 0.01));
    });

    testWidgets('blocks fill the column width whatever their label length',
        (tester) async {
      await _pump(tester, _progress());

      final folder = tester.getSize(
          find.byKey(const ValueKey('annual-block-annual_evidence_folder')));
      final finance = tester.getSize(
          find.byKey(const ValueKey('annual-block-finance_compliance')));
      expect(folder.width, finance.width);
    });

    testWidgets('skips components worth 0 points', (tester) async {
      await _pump(tester, _progress());

      expect(
        find.byKey(const ValueKey('annual-block-activities_registered')),
        findsNothing,
      );
      expect(find.text('Componente sin puntos'), findsNothing);
    });

    testWidgets('the chip goes on the component with the largest gap only',
        (tester) async {
      await _pump(tester, _progress());

      final chip = find.byKey(const ValueKey('annual-gain-chip'));
      expect(chip, findsOneWidget);
      expect(find.text('+3,000 por ganar'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('annual-block-annual_evidence_folder')),
          matching: chip,
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping a block opens the sheet with how it is earned',
        (tester) async {
      await _pump(tester, _progress());

      await tester.tap(
        find.byKey(const ValueKey('annual-block-finance_compliance')),
      );
      await tester.pumpAndSettle();

      expect(find.text('333 / 2,000 pts'), findsWidgets);
      expect(find.text('CÓMO SE GANA'), findsOneWidget);
      expect(find.textContaining('movimiento financiero'), findsOneWidget);
      expect(find.text('Eje: Administrativo'), findsOneWidget);
    });
  });

  group('Projection and pending', () {
    testWidgets('projects the points and what is still missing',
        (tester) async {
      await _pump(tester, _progress());

      expect(find.text('Llegarías a 4,439 pts'), findsOneWidget);
      expect(find.text('Te faltarían 561 para Bronce'), findsOneWidget);
      expect(find.text('Ahora 1,439'), findsOneWidget);
      expect(find.text('Carpeta +3,000'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Ahora 1,439 puntos; con la carpeta 4,439 puntos, '
          'Te faltarían 561 para Bronce',
        ),
        findsOneWidget,
      );
    });

    testWidgets('says "Alcanzarías" when the folder clears the next medal',
        (tester) async {
      await _pump(tester, _progress(currentPoints: 3000));

      expect(find.text('Llegarías a 6,000 pts'), findsOneWidget);
      expect(find.text('Alcanzarías Bronce'), findsOneWidget);
    });

    testWidgets('rows: overdue in error style, due date and status',
        (tester) async {
      await _pump(tester, _progress());

      expect(find.text('POR ENTREGAR'), findsOneWidget);
      expect(find.textContaining('Venció el'), findsOneWidget);
      expect(find.textContaining('Por entregar · vence'), findsOneWidget);
      expect(find.text('En validación'), findsOneWidget);
      expect(find.text('Ver evidencia'), findsNothing);
    });

    testWidgets('tapping a row or the footer opens the annual folder',
        (tester) async {
      var opened = 0;
      await _pump(tester, _progress(), onOpenFolder: () => opened++);

      await tester.tap(find.text('Servicio a la comunidad'));
      await tester.pump();
      expect(opened, 1);

      await tester.tap(find.text('Apartado 2'));
      await tester.pump();
      expect(opened, 2);

      await tester.tap(find.byKey(const ValueKey('annual-open-folder')));
      await tester.pump();
      expect(opened, 3);
      expect(find.text('Abrir la carpeta anual'), findsOneWidget);
    });

    testWidgets('without access to the folder there is no footer action',
        (tester) async {
      var opened = 0;
      await _pump(
        tester,
        _progress(),
        onOpenFolder: () => opened++,
        canOpenFolder: false,
      );

      expect(find.byKey(const ValueKey('annual-open-folder')), findsNothing);
      await tester.tap(find.text('Servicio a la comunidad'));
      await tester.pump();
      expect(opened, 0);
    });

    testWidgets('empty pending list keeps the all-clear row', (tester) async {
      await _pump(tester, _progress(pending: const []));

      expect(
        find.text('No hay pendientes críticos para este ranking.'),
        findsOneWidget,
      );
    });
  });
}
