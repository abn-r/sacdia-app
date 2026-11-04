import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_settings.dart';

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('group shows title and children; tile is >= 48dp and taps',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(SacSettingsGroup(
      title: 'CUENTA',
      children: [
        SacSettingsTile(
          icon: HugeIcons.strokeRoundedQrCode,
          title: 'Mi QR',
          subtitle: 'Credencial',
          onTap: () => taps++,
        ),
        const SacSettingsDivider(),
        const SacSettingsTile(
          icon: HugeIcons.strokeRoundedLogout02,
          title: 'Salir',
          destructive: true,
        ),
      ],
    )));
    expect(find.text('CUENTA'), findsOneWidget);
    expect(find.text('Credencial'), findsOneWidget);
    expect(tester.getSize(find.byType(SacSettingsTile).first).height,
        greaterThanOrEqualTo(48));
    await tester.tap(find.text('Mi QR'));
    expect(taps, 1);
  });

  testWidgets('switch tile exposes toggled semantics and toggles',
      (tester) async {
    final handle = tester.ensureSemantics();
    bool value = false;
    await tester.pumpWidget(_host(StatefulBuilder(
      builder: (context, setState) => SacSettingsSwitchTile(
        icon: HugeIcons.strokeRoundedNotification01,
        title: 'Push',
        value: value,
        onChanged: (v) => setState(() => value = v),
      ),
    )));
    expect(
      tester.getSemantics(find.bySemanticsLabel('Push')),
      matchesSemantics(
        label: 'Push',
        hasToggledState: true,
        isToggled: false,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(value, isTrue);
    handle.dispose();
  });

  testWidgets('switch tile with null onChanged is disabled', (tester) async {
    await tester.pumpWidget(_host(const SacSettingsSwitchTile(
      icon: HugeIcons.strokeRoundedNotification01,
      title: 'Push',
      value: false,
      onChanged: null,
    )));
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
  });
}
