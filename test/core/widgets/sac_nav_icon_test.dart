import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/widgets/sac_nav_icon.dart';

void main() {
  group('SacNavIcon', () {
    testWidgets('should use a heavier stroke when selected', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                SacNavIcon(icon: HugeIcons.strokeRoundedHome01),
                SacNavIcon(
                  icon: HugeIcons.strokeRoundedHome01,
                  selected: true,
                ),
              ],
            ),
          ),
        ),
      );

      final icons = tester.widgetList<HugeIcon>(find.byType(HugeIcon)).toList();
      expect(icons, hasLength(2));
      expect(icons[0].strokeWidth, SacNavIcon.idleStroke);
      expect(icons[1].strokeWidth, SacNavIcon.selectedStroke);
    });
  });
}
