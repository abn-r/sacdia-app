import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:secure_application/secure_application_native.dart';

/// Wraps a sensitive screen with platform-level content protection:
///
/// - Android: sets [FLAG_SECURE] on the Window while this widget is in the
///   tree. Prevents screenshots, screen recording, and Recents thumbnails.
///   Satisfies MASVS-PLATFORM-3.
/// - iOS: blurs the app snapshot shown in the app-switcher whenever the
///   screen goes to background while this screen is mounted. Removes the
///   native blur when the app resumes or when the screen is disposed.
///
/// The protection is scoped to the lifetime of this widget — it activates
/// on [initState] and is released on [dispose], so non-sensitive screens
/// remain unaffected.
///
/// Usage — wrap the outermost widget returned by the screen's `build`:
///
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   return SecureScreen(
///     child: Scaffold(
///       appBar: AppBar(title: const Text('Credencial')),
///       body: ...,
///     ),
///   );
/// }
/// ```
class SecureScreen extends StatefulWidget {
  const SecureScreen({super.key, required this.child});

  final Widget child;

  @override
  State<SecureScreen> createState() => _SecureScreenState();
}

class _SecureScreenState extends State<SecureScreen>
    with WidgetsBindingObserver {
  static int _activeSecureScreenCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _activeSecureScreenCount += 1;

    // Clear any stale native overlay that may have survived an app resume/hot
    // restart, then keep the current screen protected for the next background.
    if (_activeSecureScreenCount == 1) {
      _invokeNative('unlock', SecureApplicationNative.unlock);
    }
    _invokeNative('secure', SecureApplicationNative.secure);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    // secure_application adds the iOS blur in applicationWillResignActive, but
    // its low-level native API does not remove it automatically on resume.
    // Removing it here fixes the "white/dimmed screen" after opening external
    // apps (tel:, sms:, browser, maps, etc.) while keeping protection enabled.
    _invokeNative('unlock', SecureApplicationNative.unlock);
    if (_activeSecureScreenCount > 0) {
      _invokeNative('secure', SecureApplicationNative.secure);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_activeSecureScreenCount > 0) {
      _activeSecureScreenCount -= 1;
    }

    // Remove the native overlay even when this route is destroyed while the
    // blur is visible. Only disable protection after the last SecureScreen
    // leaves the tree, because secure screens may be nested.
    _invokeNative('unlock', SecureApplicationNative.unlock);
    if (_activeSecureScreenCount == 0) {
      _invokeNative('open', SecureApplicationNative.open);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void _invokeNative(String action, Future<dynamic> Function() call) {
    unawaited(_invokeNativeSafely(action, call));
  }

  Future<void> _invokeNativeSafely(
    String action,
    Future<dynamic> Function() call,
  ) async {
    try {
      await call();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('SecureScreen native $action failed: $error');
      }
    }
  }
}
