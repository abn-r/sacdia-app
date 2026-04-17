/// Feature flags for the realtime invalidation subsystem.
///
/// All flags default to FALSE for a safe, dark-launch rollout. Flip the
/// compile-time constant via --dart-define when enabling per-environment.
///
/// Example (dart-define):
///   flutter run --dart-define=REALTIME_INVALIDATION_ENABLED=true
class RealtimeFeatureFlags {
  const RealtimeFeatureFlags._();

  /// When true, foreground and background FCM INVALIDATE messages trigger
  /// provider cache invalidation in the app.
  ///
  /// Keep false until the backend is fully deployed and the FCM payload
  /// format has been validated in production traffic.
  static const bool realtimeInvalidationEnabled = bool.fromEnvironment(
    'REALTIME_INVALIDATION_ENABLED',
    defaultValue: false,
  );
}
