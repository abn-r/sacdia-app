import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/widgets/fixed_input_icon_slot.dart';

void main() {
  testWidgets('keeps the input icon and slot at fixed sizes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextField(
            decoration: InputDecoration(
              prefixIconConstraints: FixedInputIconSlot.constraints,
              prefixIcon: const FixedInputIconSlot(
                iconSlotKey: ValueKey('fixed-input-icon-slot'),
                icon: HugeIcons.strokeRoundedSearch01,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    );

    final iconSlot = find.byKey(const ValueKey('fixed-input-icon-slot'));
    expect(iconSlot, findsOneWidget);
    expect(tester.getSize(iconSlot), const Size(20, 20));

    final textField = tester.widget<TextField>(find.byType(TextField));
    final constraints = textField.decoration?.prefixIconConstraints;
    expect(constraints, isNotNull);
    expect(constraints?.minWidth, 48);
    expect(constraints?.maxWidth, 48);
    expect(constraints?.minHeight, 48);
    expect(constraints?.maxHeight, 48);
  });
}
