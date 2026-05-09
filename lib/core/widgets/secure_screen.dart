import 'package:flutter/material.dart';
import 'package:secure_application/secure_application_native.dart';

/// Wraps a sensitive screen with platform-level content protection:
///
/// - Android: sets [FLAG_SECURE] on the Window while this widget is in the
///   tree. Prevents screenshots, screen recording, and Recents thumbnails.
///   Satisfies MASVS-PLATFORM-3.
/// - iOS: blurs the app snapshot shown in the app-switcher whenever the
///   screen goes to background while this screen is mounted. Removes blur
///   when the screen is disposed (user navigated away).
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

class _SecureScreenState extends State<SecureScreen> {
  @override
  void initState() {
    super.initState();
    // Activates FLAG_SECURE (Android) and iOS app-switcher blur immediately.
    SecureApplicationNative.secure();
  }

  @override
  void dispose() {
    // Lifts the FLAG_SECURE / blur when navigating away from this screen so
    // non-sensitive screens are not affected.
    SecureApplicationNative.open();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
