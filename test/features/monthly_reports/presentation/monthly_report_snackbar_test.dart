import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/monthly_reports/presentation/widgets/monthly_report_motion.dart';

void main() {
  testWidgets(
    'keeps monthly report snackbars visible above shell navigation',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      monthlyReportSnackBar(
                        content: const Text('Downloading report'),
                      ),
                    );
                  },
                  child: const Text('Show snackbar'),
                ),
              ),
            ),
            bottomNavigationBar: NavigationBar(
              destinations: [
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
}
