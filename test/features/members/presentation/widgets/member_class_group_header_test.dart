import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/members/presentation/widgets/member_class_group_header.dart';

void main() {
  Widget buildSubject({required String label, required int count}) {
    return MaterialApp(
      home: Scaffold(
        body: MemberClassGroupHeader(label: label, count: count),
      ),
    );
  }

  testWidgets('shows the mapped class logo next to the group label', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(label: 'Amigo', count: 5));

    expect(
      find.byKey(const ValueKey('member-class-logo-Amigo')),
      findsOneWidget,
    );
    expect(find.text('AMIGO'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);

    final image = tester.widget<Image>(
      find.byKey(const ValueKey('member-class-logo-Amigo')),
    );
    expect(
      (image.image as AssetImage).assetName,
      'assets/img/logos-clases/CQ-01.png',
    );
  });

  testWidgets('does not show a logo for the unassigned class group', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(label: 'Sin clase', count: 1));

    expect(
      find.byKey(const ValueKey('member-class-logo-Sin clase')),
      findsNothing,
    );
    expect(find.text('SIN CLASE'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });
}
