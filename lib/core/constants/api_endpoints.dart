/// Centralized API endpoint path segments.
///
/// [AppConstants.baseUrl] already includes the `/api/v1` prefix
/// (e.g. `http://localhost:3000/api/v1`). These constants define only
/// the resource path segments that follow the base URL.
///
/// When the API version changes, only [AppConstants.baseUrl] needs updating.
/// When a resource path changes, only this file needs updating.
///
/// Usage:
/// ```dart
/// final response = await _dio.get('$_baseUrl${ApiEndpoints.honors}/categories');
/// ```
class ApiEndpoints {
  const ApiEndpoints._();

  // ── Auth ──────────────────────────────────────────────────────────────────
  static const String auth = '/auth';

  // ── Users ─────────────────────────────────────────────────────────────────
  static const String users = '/users';

  // ── Clubs ─────────────────────────────────────────────────────────────────
  static const String clubs = '/clubs';

  // ── Club Sections ─────────────────────────────────────────────────────────
  static const String clubSections = '/club-sections';
  static const String membershipRequests = '/membership-requests';

  // ── Club Roles ────────────────────────────────────────────────────────────
  static const String clubRoles = '/club-roles';

  // ── Dashboard ─────────────────────────────────────────────────────────────
  static const String dashboard = '/dashboard';

  // ── Classes ───────────────────────────────────────────────────────────────
  static const String classes = '/classes';

  // ── Honors ────────────────────────────────────────────────────────────────
  static const String honors = '/honors';

  // ── Activities ────────────────────────────────────────────────────────────
  static const String activities = '/activities';

  // ── Finances ──────────────────────────────────────────────────────────────
  static const String finances = '/finances';

  // ── Camporees ─────────────────────────────────────────────────────────────
  static const String camporees = '/camporees';

  // ── Annual Folders ────────────────────────────────────────────────────────
  static const String annualFolders = '/annual-folders';

  // ── Monthly Reports ───────────────────────────────────────────────────────
  static const String monthlyReports = '/monthly-reports';

  // ── Members / Enrollment ──────────────────────────────────────────────────
  static const String enrollments = '/enrollments';

  // ── Investiture ───────────────────────────────────────────────────────────
  static const String investiture = '/investiture';

  // ── Validation ────────────────────────────────────────────────────────────
  static const String validation = '/validation';

  // ── Certifications ────────────────────────────────────────────────────────
  static const String certifications = '/certifications';

  // ── Inventory ─────────────────────────────────────────────────────────────
  static const String inventory = '/inventory';

  // ── Insurance ─────────────────────────────────────────────────────────────
  static const String insurance = '/insurance';

  // ── Resources ─────────────────────────────────────────────────────────────
  static const String resources = '/resources';
  static const String resourceCategories = '/resource-categories';

  // ── Catalogs ──────────────────────────────────────────────────────────────
  static const String catalogs = '/catalogs';

  // ── Transfers / Requests ──────────────────────────────────────────────────
  static const String requests = '/requests';

  // ── Notifications ─────────────────────────────────────────────────────────
  static const String notifications = '/notifications';

  // ── Evidence Review ────────────────────────────────────────────────────────
  static const String evidenceReview = '/evidence-review';

  // ── Admin Analytics ───────────────────────────────────────────────────────
  static const String adminAnalytics = '/admin/analytics';
}
