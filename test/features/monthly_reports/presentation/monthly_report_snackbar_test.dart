import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';

void main() {
  group('SacSnackBar monthly reports', () {
    testWidgets(
      'should stay visible above shell navigation when behavior is fixed',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () {
                      SacSnackBar.show(
                        context,
                        'Downloading report',
                        behavior: SnackBarBehavior.fixed,
                      );
                    },
                    child: const Text('Show snackbar'),
                  ),
                ),
              ),
              bottomNavigationBar: NavigationBar(
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show snackbar'));
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('Downloading report'), findsOneWidget);
      },
    );
  });
}
