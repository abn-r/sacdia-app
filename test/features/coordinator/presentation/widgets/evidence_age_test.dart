import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/coordinator/presentation/widgets/evidence_age.dart';

import '../../coordinator_test_harness.dart';

void main() {
  setUpAll(initCoordinatorTestLocalization);

  final now = DateTime(2026, 10, 22, 12);
  EvidenceAge ageOf(Duration ago) =>
      EvidenceAge.of(now.subtract(ago), now: now);

  group('EvidenceAge.of', () {
    test('thresholds are 3 days (warning) and 7 days (overdue)', () {
      expect(kEvidenceWarningDays, 3);
      expect(kEvidenceOverdueDays, 7);
    });

    test('under 3 days is fresh', () {
      expect(ageOf(const Duration(hours: 5)).level, EvidenceAgeLevel.fresh);
      expect(ageOf(const Duration(days: 2, hours: 23)).level,
          EvidenceAgeLevel.fresh);
    });

    test('3 to 6 days is warning', () {
      expect(ageOf(const Duration(days: 3)).level, EvidenceAgeLevel.warning);
      expect(ageOf(const Duration(days: 6, hours: 23)).level,
          EvidenceAgeLevel.warning);
    });

    test('7 days or more is overdue', () {
      expect(ageOf(const Duration(days: 7)).level, EvidenceAgeLevel.overdue);
      expect(ageOf(const Duration(days: 40)).isOverdue, isTrue);
      expect(ageOf(const Duration(days: 40)).days, 40);
    });

    test('a future submission (clock skew) counts as today', () {
      final age = EvidenceAge.of(now.add(const Duration(days: 2)), now: now);
      expect(age.days, 0);
      expect(age.level, EvidenceAgeLevel.fresh);
    });
  });

  group('EvidenceAge.label', () {
    testWidgets('Hoy, Hace N d and Vencida · N d', (tester) async {
      late List<String> labels;
      await tester.pumpWidget(
        localized(
          (context) => localizedApp(
            context,
            Builder(
              builder: (_) {
                labels = [
                  ageOf(const Duration(hours: 3)).label,
                  ageOf(const Duration(days: 2)).label,
                  ageOf(const Duration(days: 5)).label,
                  ageOf(const Duration(days: 9)).label,
                ];
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(labels, ['Hoy', 'Hace 2 d', 'Hace 5 d', 'Vencida · 9 d']);
    });
  });
}
