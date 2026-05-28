import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/rankings/domain/entities/annual_ranking_progress.dart';
import 'package:sacdia_app/features/rankings/presentation/screens/club_rankings_screen.dart';

void main() {
  group('Annual ranking progress UI', () {
    testWidgets('shows only the active section scorecard, not a leaderboard',
        (tester) async {
      await _pumpProgress(tester);

      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text('rankings.club_rankings.clubs_ranked'), findsNothing);
      expect(find.text('Club Halcones'), findsNothing);
      expect(find.textContaining(RegExp(r'7[,.]200')), findsWidgets);
      expect(find.text('Oro'), findsOneWidget);
    });

    testWidgets('renders i18n status labels instead of raw backend statuses',
        (tester) async {
      await _pumpProgress(tester);
      await tester.drag(find.byType(ListView), const Offset(0, -520));
      await tester.pumpAndSettle();

      expect(find.text('IN_PROGRESS'), findsNothing);
      expect(
        find.text('rankings.annual_progress.pending.status.pending_validation'),
        findsOneWidget,
      );
    });
  });
}

Future<void> _pumpProgress(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AnnualRankingProgressContent(
          progress: _progress(),
          yearName: '2025-2026',
          onRefresh: () async {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

AnnualRankingProgress _progress() {
  return AnnualRankingProgress(
    sectionId: 2,
    clubId: 1,
    clubName: 'Club Águilas',
    clubType: const RankingClubType(
      clubTypeId: 1,
      name: 'Aventureros',
    ),
    year: const RankingYear(ecclesiasticalYearId: 1),
    currentPoints: 7200,
    maxPoints: 12000,
    progressPercentage: 60,
    currentTier: const RankingTier(
      name: 'Plata',
      slug: 'silver',
      fromPoints: 6500,
      toPoints: 8499,
    ),
    nextTier: const RankingTier(
      name: 'Oro',
      slug: 'gold',
      fromPoints: 8500,
      toPoints: 10499,
      pointsToReach: 1300,
    ),
    components: const [
      RankingComponentProgress(
        key: 'annual_folder',
        label: 'Carpeta anual',
        earnedPoints: 4200,
        maxPoints: 6000,
        progressPercentage: 70,
      ),
      RankingComponentProgress(
        key: 'monthly_reports',
        label: 'Reportes mensuales',
        earnedPoints: 3000,
        maxPoints: 6000,
        progressPercentage: 50,
      ),
    ],
    pendingItems: [
      RankingPendingItem(
        type: 'investiture',
        title: 'Validar investidura',
        status: 'IN_PROGRESS',
        statusLabelKey:
            'rankings.annual_progress.pending.status.pending_validation',
        dueDate: DateTime(2026, 6, 1),
        actionLabel: 'Enviar evidencias',
      ),
    ],
  );
}
