import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/status_progress/status_progress.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.lightTheme,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pump();
}

void main() {
  test('StatusCounts derives total, ready and missing', () {
    const counts =
        StatusCounts(validated: 3, review: 2, rejected: 1, pending: 4);
    expect(counts.total, 10);
    expect(counts.ready, 5);
    expect(counts.missing, 5);
  });

  for (final dark in [false, true]) {
    final theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
    final mode = dark ? 'dark' : 'light';

    testWidgets('SacStatusBar renders segments and legend ($mode)',
        (tester) async {
      await _pump(
        tester,
        const SacStatusBar(
          key: ValueKey('bar'),
          segments: [
            SacStatusSegment(count: 2, color: Colors.green, label: '2 ready'),
            SacStatusSegment(count: 0, color: Colors.red, label: '0 no'),
            SacStatusSegment(count: 1, color: Colors.grey, label: '1 waiting'),
          ],
        ),
        theme: theme,
      );
      final segments = find.descendant(
        of: find.byKey(const ValueKey('bar')),
        matching: find.byType(ColoredBox),
      );
      expect(segments, findsNWidgets(2));
      expect(tester.getSize(segments.first).height, 8);
      expect(
          find.textContaining('2 ready', findRichText: true), findsOneWidget);
      expect(find.textContaining('0 no', findRichText: true), findsNothing);
    });

    testWidgets('SacStatusBar.counts has four groups ($mode)', (tester) async {
      await _pump(
        tester,
        const SacStatusBar.counts(
          counts:
              StatusCounts(validated: 1, review: 1, rejected: 1, pending: 1),
          countLabels: SacStatusCountLabels(
            validated: 'v',
            review: 'r',
            rejected: 'x',
            pending: 'p',
          ),
        ),
        theme: theme,
      );
      expect(find.byType(ColoredBox), findsAtLeastNWidgets(4));
    });

    testWidgets('rows, group, summary and panel render ($mode)',
        (tester) async {
      var tapped = 0;
      await _pump(
        tester,
        Builder(
          builder: (context) {
            final style = SacStatusStyle.of(
              context,
              SacStatusKind.rejected,
              label: 'Rejected',
            );
            return Column(
              children: [
                SacSummaryBox(color: style.container, child: const Text('box')),
                SacGroupedSection(
                  label: 'Group',
                  children: [
                    SacStatusRow(
                      style: style,
                      title: 'Title',
                      detail: 'Detail',
                      detailIsError: true,
                      onTap: () => tapped++,
                    ),
                    SacStatusRow(
                      style: style,
                      title: 'Other',
                      detail: 'More',
                      trailing: const Text('end'),
                      onTap: () {},
                    ),
                  ],
                ),
                SacStatusPanel(
                  style: style,
                  trailing: '1/2',
                  meta: 'Fix it',
                  steps: const ['A', 'B', 'C'],
                  currentStep: 1,
                  fill: 0.5,
                  stepsSemanticsLabel: 'Step 2 of 3',
                  note: const Text('note'),
                ),
              ],
            );
          },
        ),
        theme: theme,
      );
      expect(find.text('GROUP'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Rejected'), findsOneWidget);
      expect(find.text('note'), findsOneWidget);
      expect(find.bySemanticsLabel('Step 2 of 3'), findsOneWidget);
      await tester.tap(find.text('Title'));
      expect(tapped, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('SacStatusBar exposes one Semantics label with its legend',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      const SacStatusBar(
        segments: [
          SacStatusSegment(count: 3, color: Colors.green, label: '3 invest'),
          SacStatusSegment(count: 1, color: Colors.red, label: '1 reject'),
        ],
      ),
    );
    expect(find.bySemanticsLabel('3 invest, 1 reject'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('SacStatusBar is empty when every count is zero', (tester) async {
    await _pump(
      tester,
      const SacStatusBar(
        key: ValueKey('bar'),
        segments: [SacStatusSegment(count: 0, color: Colors.red, label: 'no')],
      ),
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('bar')),
        matching: find.byType(ColoredBox),
      ),
      findsNothing,
    );
  });
}
