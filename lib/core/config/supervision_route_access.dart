import 'route_names.dart';

/// Routes a territorial supervisor (Union / Division) without a club can open
/// (see `isSupervisorWithoutClub`).
///
/// Home is `/home/dashboard`, which draws the supervision hub. Besides the hub
/// and its functions (`/supervision/...`) the supervisor keeps the profile, the
/// notifications inbox and «Mi familia» (reached from the profile when the
/// person is also a guardian). Club-only tabs and screens stay out.
///
/// The PDF viewer used by the reports function is opened with
/// `SacPdfViewer.show` (a pushed route outside go_router), so it needs no entry
/// here. Editing the profile, settings and sign out are pushed from the
/// profile the same way.
const Set<String> _supervisionExactPaths = {
  RouteNames.homeDashboard,
  RouteNames.homeProfile,
  RouteNames.homeMedicalInfo,
  RouteNames.notificationsInbox,
  // Destination of the catalog route guard: no mode bounces it.
  RouteNames.accessDenied,
};

/// Whole subtrees: the hub and its functions, and «Mi familia».
const List<String> _supervisionPrefixes = [
  RouteNames.supervision,
  RouteNames.family,
];

/// Can a club-less supervisor open [path]? (resolved path, no query).
bool isSupervisionAllowedPath(String path) {
  final normalized = path.length > 1 && path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;
  if (_supervisionExactPaths.contains(normalized)) return true;
  return _supervisionPrefixes.any(
    (prefix) => normalized == prefix || normalized.startsWith('$prefix/'),
  );
}

/// Territory level the server reports for a supervisor whose union or
/// division has not been set yet.
const String kUnconfiguredTerritoryLevel = 'unconfigured';

/// Without a configured territory no supervision function exists: any route
/// below the hub goes back to the hub, which explains the state. Returns null
/// when [path] can stay.
///
/// Some capabilities depend only on the role, so the catalog guard alone would
/// let a deep link open an empty queue.
String? unconfiguredSupervisionRedirect({
  required String? territoryLevel,
  required String path,
}) {
  if (territoryLevel != kUnconfiguredTerritoryLevel) return null;
  return path.startsWith('${RouteNames.supervision}/')
      ? RouteNames.supervision
      : null;
}
