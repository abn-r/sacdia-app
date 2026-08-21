import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/utils/in_app_browser.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  group('openInAppDocument', () {
    final uri = Uri.parse('https://sacdia.com/privacy');

    test('should use the in-app browser when the platform supports it',
        () async {
      LaunchMode? usedMode;
      final opened = await openInAppDocument(
        uri,
        supportsMode: (mode) async => mode == LaunchMode.inAppBrowserView,
        launch: (url,
            {mode = LaunchMode.platformDefault,
            browserConfiguration = const BrowserConfiguration()}) async {
          usedMode = mode;
          return true;
        },
      );

      expect(opened, isTrue);
      expect(usedMode, LaunchMode.inAppBrowserView);
    });

    test('should fall back to the system browser if in-app launch fails',
        () async {
      final modes = <LaunchMode>[];
      final opened = await openInAppDocument(
        uri,
        supportsMode: (mode) async => mode == LaunchMode.inAppBrowserView,
        launch: (url,
            {mode = LaunchMode.platformDefault,
            browserConfiguration = const BrowserConfiguration()}) async {
          modes.add(mode);
          return mode == LaunchMode.externalApplication;
        },
      );

      expect(opened, isTrue);
      expect(modes, [
        LaunchMode.inAppBrowserView,
        LaunchMode.externalApplication,
      ]);
    });

    test('should use the system browser when in-app mode is unsupported',
        () async {
      LaunchMode? usedMode;
      final opened = await openInAppDocument(
        uri,
        supportsMode: (_) async => false,
        launch: (url,
            {mode = LaunchMode.platformDefault,
            browserConfiguration = const BrowserConfiguration()}) async {
          usedMode = mode;
          return true;
        },
      );

      expect(opened, isTrue);
      expect(usedMode, LaunchMode.externalApplication);
    });

    test('should reject non-http URIs', () async {
      var launched = false;
      final opened = await openInAppDocument(
        Uri.parse('mailto:sacdia.app@gmail.com'),
        supportsMode: (_) async => true,
        launch: (url,
            {mode = LaunchMode.platformDefault,
            browserConfiguration = const BrowserConfiguration()}) async {
          launched = true;
          return true;
        },
      );

      expect(opened, isFalse);
      expect(launched, isFalse);
    });
  });
}
