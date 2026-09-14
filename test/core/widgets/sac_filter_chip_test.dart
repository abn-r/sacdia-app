import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_filter_chip.dart';

void main() {
  group('SacFilterChip', () {
    testWidgets('should fill primary when selected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: SacFilterChip(
              label: 'Todos',
              selected: true,
              onTap: null,
            ),
          ),
        ),
      );

      expect(find.text('Todos'), findsOneWidget);
      final box =
          tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, AppColors.primary);
    });

    testWidgets('should fire onTap when enabled chip is tapped',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SacFilterChip(
              label: 'Clases',
              selected: false,
              icon: HugeIcons.strokeRoundedGridView,
              onTap: () => taps++,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Clases'));
      expect(taps, 1);
    });
  });
}
