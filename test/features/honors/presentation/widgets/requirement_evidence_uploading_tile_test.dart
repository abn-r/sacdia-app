import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_requirement_evidence.dart';

import '../../../../support/l10n_test_support.dart';

void main() {
  setUpAll(loadSpanishTranslations);

  final percent = find.byKey(
    const ValueKey('requirement-evidence-upload-percent'),
  );

  Future<void> pumpTile(
    WidgetTester tester, {
    required double progress,
    bool done = false,
    VoidCallback? onSettled,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RequirementEvidenceUploadingTile(
              file: File('/tmp/does-not-exist.pdf'),
              progress: progress,
              done: done,
              onSettled: onSettled ?? () {},
            ),
          ),
        ),
      ),
    );
  }

  String shownPercent(WidgetTester tester) =>
      tester.widget<Text>(percent).data!;

  testWidgets('a fast upload still sweeps from 0 to 100', (tester) async {
    await pumpTile(tester, progress: 0);
    expect(shownPercent(tester), '0%');

    // The whole file is reported sent at once.
    await pumpTile(tester, progress: 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 200));
    final mid = int.parse(shownPercent(tester).replaceAll('%', ''));
    expect(mid, inInclusiveRange(1, 99));

    await tester.pump(const Duration(milliseconds: 500));
    // Full but not confirmed yet: saving spinner, no percentage.
    expect(percent, findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the check once done, then hands over', (tester) async {
    var settled = 0;
    await pumpTile(tester, progress: 0, onSettled: () => settled++);
    await pumpTile(
      tester,
      progress: 1,
      done: true,
      onSettled: () => settled++,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byKey(const ValueKey('check')), findsOneWidget);
    expect(settled, 0);

    await tester.pump(const Duration(milliseconds: 700));
    expect(settled, 1);
  });
}
