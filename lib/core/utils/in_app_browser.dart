import 'package:url_launcher/url_launcher.dart';

typedef LaunchUrlFn = Future<bool> Function(
  Uri url, {
  LaunchMode mode,
  BrowserConfiguration browserConfiguration,
});

typedef SupportsLaunchModeFn = Future<bool> Function(LaunchMode mode);

/// Opens HTTPS documents inside the app: SFSafariViewController on iOS,
/// Chrome Custom Tabs on Android. Falls back to the system browser.
Future<bool> openInAppDocument(
  Uri uri, {
  LaunchUrlFn launch = launchUrl,
  SupportsLaunchModeFn supportsMode = supportsLaunchMode,
}) async {
  if (uri.scheme != 'https' && uri.scheme != 'http') return false;

  try {
    if (await supportsMode(LaunchMode.inAppBrowserView)) {
      final opened = await launch(
        uri,
        mode: LaunchMode.inAppBrowserView,
        browserConfiguration: const BrowserConfiguration(showTitle: true),
      );
      if (opened) return true;
    }

    return launch(
      uri,
      mode: LaunchMode.externalApplication,
      browserConfiguration: const BrowserConfiguration(),
    );
  } catch (_) {
    return false;
  }
}
