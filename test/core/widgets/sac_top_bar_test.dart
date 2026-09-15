import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';

void main() {
  group('SacTopBar', () {
    testWidgets('should include TabBar height in preferredSize',
        (tester) async {
      const tabs = TabBar(
        tabs: [
          Tab(text: 'Local'),
          Tab(text: 'Unión'),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: const SacTopBar(
                title: 'Aprobaciones',
                automaticallyImplyLeading: false,
                bottom: tabs,
              ),
            ),
          ),
        ),
      );

      final bar = tester.widget<SacTopBar>(find.byType(SacTopBar));
      expect(
        bar.preferredSize.height,
        SacTopBar.compactHeight +
            SacTopBar.borderHeight +
            tabs.preferredSize.height,
      );
      expect(find.text('Local'), findsOneWidget);
      expect(find.text('Unión'), findsOneWidget);
    });
  });
}
