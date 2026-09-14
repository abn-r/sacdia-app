import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';

void main() {
  testWidgets('hides the previous snackbar before showing a new one',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                SacSnackBar.show(context, 'primero');
                SacSnackBar.show(context, 'segundo');
              },
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pump();

    expect(find.text('primero'), findsNothing);
    expect(find.text('segundo'), findsOneWidget);
  });

  testWidgets('error toast uses the error color', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => SacSnackBar.show(context, 'boom', isError: true),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pump();

    final bar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(bar.backgroundColor, AppColors.error);
    expect(find.text('boom'), findsOneWidget);
  });
}
