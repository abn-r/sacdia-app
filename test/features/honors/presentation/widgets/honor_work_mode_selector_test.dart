import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_work_mode_selector.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }

  testWidgets('calls back with in-app mode', (tester) async {
    HonorCompletionMode? selected;

    await tester.pumpWidget(
      wrap(
        HonorWorkModeSelector(
          categoryColor: Colors.blue,
          onSelected: (mode) => selected = mode,
        ),
      ),
    );

    await tester.tap(find.text('honors.work_mode.in_app_title'));
    await tester.pump();

    expect(selected, HonorCompletionMode.inApp);
  });

  testWidgets('disables mode choices while saving', (tester) async {
    HonorCompletionMode? selected;

    await tester.pumpWidget(
      wrap(
        HonorWorkModeSelector(
          categoryColor: Colors.blue,
          isLoading: true,
          onSelected: (mode) => selected = mode,
        ),
      ),
    );

    await tester.tap(find.text('honors.work_mode.external_title'));
    await tester.pump();

    expect(selected, isNull);
    expect(find.text('honors.work_mode.saving'), findsOneWidget);
  });
}
