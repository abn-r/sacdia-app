import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/virtual_card/presentation/utils/share_position_origin.dart';

void main() {
  testWidgets('returns a non-zero rect from the share button render box',
      (tester) async {
    final originKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              key: originKey,
              width: 160,
              height: 48,
              child: const Text('Share'),
            ),
          ),
        ),
      ),
    );

    final rect = sharePositionOriginForContext(originKey.currentContext!);

    expect(rect, isNotNull);
    expect(rect!.width, 160);
    expect(rect.height, 48);
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.top, greaterThanOrEqualTo(0));
  });
}
