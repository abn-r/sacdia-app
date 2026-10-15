import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/features/qr/presentation/views/qr_scanner_view.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: child),
      );

  testWidgets('permission denied offers open settings and retry',
      (tester) async {
    var openedSettings = 0;
    var retried = 0;
    await tester.pumpWidget(host(
      QrCameraErrorView(
        errorCode: MobileScannerErrorCode.permissionDenied,
        onRetry: () => retried++,
        onOpenSettings: () async {
          openedSettings++;
          return true;
        },
      ),
    ));

    expect(find.text('Camera permission denied.'), findsNothing);
    expect(find.text('qr.camera.permission_denied_title'), findsOneWidget);

    await tester.tap(find.text('qr.camera.open_settings'));
    await tester.tap(find.text('common.retry'));
    expect(openedSettings, 1);
    expect(retried, 1);
  });

  testWidgets('other camera errors only offer retry', (tester) async {
    await tester.pumpWidget(host(
      QrCameraErrorView(
        errorCode: MobileScannerErrorCode.genericError,
        onRetry: () {},
        onOpenSettings: () async => true,
      ),
    ));

    expect(find.text('qr.camera.unavailable_title'), findsOneWidget);
    expect(find.text('qr.camera.open_settings'), findsNothing);
    expect(find.text('common.retry'), findsOneWidget);
  });
}
