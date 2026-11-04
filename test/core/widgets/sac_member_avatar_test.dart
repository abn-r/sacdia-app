import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_member_avatar.dart';

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  test('initialsOf uses first letters of first two words', () {
    expect(SacMemberAvatar.initialsOf('ana maría pérez'), 'AM');
    expect(SacMemberAvatar.initialsOf('  luis '), 'L');
    expect(SacMemberAvatar.initialsOf(''), '');
  });

  testWidgets('shows initials and semantics label without image',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(const SacMemberAvatar(name: 'ana maría')));
    expect(find.text('AM'), findsOneWidget);
    expect(find.bySemanticsLabel('ana maría'), findsOneWidget);
    expect(tester.getSize(find.byType(SacMemberAvatar)), const Size(40, 40));
    handle.dispose();
  });

  testWidgets('custom semanticLabel, size and ring', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(const SacMemberAvatar(
      name: 'Juan Pérez',
      size: 64,
      ring: true,
      semanticLabel: 'Foto de Juan',
    )));
    expect(find.bySemanticsLabel('Foto de Juan'), findsOneWidget);
    expect(tester.getSize(find.byType(SacMemberAvatar)), const Size(64, 64));
    expect(find.text('JP'), findsOneWidget);
    handle.dispose();
  });
}
