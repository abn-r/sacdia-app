import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/features/classes/domain/entities/class_section.dart';
import 'package:sacdia_app/features/classes/presentation/widgets/section_checkbox.dart';

void main() {
  group('SectionCheckbox', () {
    testWidgets('should scale only the circle while the row is pressed',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SectionCheckbox(
              section: const ClassSection(
                id: 1,
                name: 'Nudos',
                moduleId: 4,
              ),
              onChanged: (_) {},
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Nudos')),
      );
      await tester.pump();

      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        SacMotion.pressScale,
      );

      await gesture.up();
    });

    testWidgets('should show the tick when the section is completed',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SectionCheckbox(
              section: const ClassSection(
                id: 1,
                name: 'Nudos',
                moduleId: 4,
                isCompleted: true,
              ),
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(HugeIcon), findsOneWidget);
    });
  });
}
