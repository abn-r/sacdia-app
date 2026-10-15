import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/classes/presentation/roadmap/widgets/roadmap_screen.dart';

void main() {
  testWidgets('pulling down the roadmap calls onRefresh', (tester) async {
    var refreshes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoadmapScreen(
            tracks: const [],
            onRefresh: () async => refreshes++,
          ),
        ),
      ),
    );

    await tester.drag(find.byType(Scrollable), const Offset(0, 500));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(refreshes, 1);
  });

  testWidgets('without onRefresh there is no refresh indicator',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RoadmapScreen(tracks: [])),
      ),
    );

    expect(find.byType(RefreshIndicator), findsNothing);
  });
}
