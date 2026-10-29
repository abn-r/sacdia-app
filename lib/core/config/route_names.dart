/// Constantes para los nombres y paths de las rutas de la aplicación
class RouteNames {
  RouteNames._();

  // Paths
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String postRegistration = '/post-registration';
  static const String legalAcceptance = '/legal-acceptance';
  static const String home = '/home';
  static const String dashboard = 'dashboard';
  static const String classes = 'classes';
  static const String activities = 'activities';
  static const String profile = 'profile';
  static const String clubDetail = '/club/:clubId';
  static const String classDetail = '/class/:classId';
  static const String honorDetail = '/honor/:honorId';
  static const String activityDetail = '/activity/:activityId';

  // Paths completos para tabs del home
  static const String homeDashboard = '/home/dashboard';
  static const String homeClasses = '/home/classes';
  static const String homeActivities = '/home/activities';
  static const String homeProfile = '/home/profile';

  // Roadmap de clases (pantalla completa dentro del branch de Clases)
  static const String homeClassesRoadmap = '/home/classes/roadmap';

  // Módulos de acceso rápido (dentro del shell)
  static const String homeMembers = '/home/members';

  /// Miembros abierto en la pestaña Solicitudes (`?tab=requests`).
  static const String homeMemberRequests = '/home/members?tab=requests';
  static const String homeClub = '/home/club';
  static const String homeEvidences = '/home/evidences';
  static const String homeFinances = '/home/finances';
  static const String homeUnits = '/home/units';
  static const String homeGroupedClass = '/home/grouped-class';
  static const String homeInsurance = '/home/insurance';
  static const String homeInventory = '/home/inventory';
  static const String homeResources = '/home/resources';
  static const String homeReports = '/home/reports';
  static const String homeHonors = '/home/honors';
  static const String homeCertifications = '/home/certifications';
  static const String homeAchievements = '/home/achievements';
  static const String homeMasterHonors = '/home/master-honors';

  // Información médica del usuario (detalle fuera del shell)
  static const String homeMedicalInfo = '/home/medical-info';

  // Rutas de detalle fuera del shell
  static const String certificationDetail = '/certification/:certificationId';
  static const String certificationProgress =
      '/certification/:certificationId/progress/:enrollmentId';

  // Ejecución de requisitos y cierre de certificación (Fase 5)
  static const String certificationRequirementDetail =
      '/certification/:certificationId/requirement/:sectionId';
  static const String certificationCloseout =
      '/certification/:certificationId/closeout';

  // Camporees
  static const String homeCamporees = '/home/camporees';
  static const String camporeeDetail = '/camporee/:camporeeId';
  static const String camporeeMembers = '/camporee/:camporeeId/members';
  static const String camporeeRegisterMember = '/camporee/:camporeeId/register';
  // Keep this outside `/camporee/:camporeeId` or GoRouter treats
  // "judge-assignments" as a camporee id and opens CamporeeDetailView(0).
  static const String camporeeJudgeAssignments = '/judge-assignments';
  static const String camporeeJudgeScoreEntry =
      '/camporee-events/:eventId/sections/:clubSectionId/score';

  // Traslados
  static const String transferRequests = '/transfers';
  static const String transferRequestDetailRoute = '/transfer/:requestId';

  // Investidura por autorización
  static const String sectionInvestiture = '/home/investiture';
  static const String sectionInvestitureHistory = '/home/investiture/history';
  static const String ownInvestiture = '/investiture/mine';

  // Autorizador de investiduras (pastor, director-lf, assistant-lf). La ruta
  // del listado coincide con la del catálogo de pantallas del panel
  // (`app-investiture-authorizer`).
  static const String investitureAuthorize = '/investiture/authorize';
  static const String investitureAuthorizeDetail =
      '/investiture/authorize/:requestId';

  // Carga masiva por comprobante/certificado OCR
  static const String certificateImportUpload = '/certificate-import';
  static const String certificateImportReview =
      '/certificate-import/:batchId/review';
  static const String certificateImportStatus =
      '/certificate-import/:batchId/status';
  static const String certificateImportProof =
      '/certificate-import/:batchId/proof/:fileId';

  // Helpers para paths con parámetros
  static String clubDetailPath(String clubId) => '/club/$clubId';
  static String classDetailPath(
    String classId, {
    int? enrollmentId,
    String? targetUserId,
  }) {
    final queryParameters = <String, String>{
      if (enrollmentId != null) 'enrollmentId': enrollmentId.toString(),
      if (targetUserId != null && targetUserId.isNotEmpty)
        'targetUserId': targetUserId,
    };
    final query = Uri(queryParameters: queryParameters).query;
    return query.isEmpty ? '/class/$classId' : '/class/$classId?$query';
  }

  static String investitureAuthorizeDetailPath(String requestId) =>
      '/investiture/authorize/${Uri.encodeComponent(requestId)}';

  static String honorDetailPath(String honorId) => '/honor/$honorId';
  static String activityDetailPath(int activityId) => '/activity/$activityId';
  static String certificationDetailPath(String certificationId) =>
      '/certification/$certificationId';
  static String certificationProgressPath(
    String certificationId,
    String enrollmentId,
  ) =>
      '/certification/$certificationId/progress/$enrollmentId';
  static String certificationRequirementDetailPath(
    int certificationId,
    int sectionId, {
    required int enrollmentId,
  }) =>
      '/certification/$certificationId/requirement/$sectionId'
      '?enrollmentId=$enrollmentId';
  static String certificationCloseoutPath(
    int certificationId, {
    required int enrollmentId,
    String? certificationName,
  }) {
    final base = '/certification/$certificationId/closeout'
        '?enrollmentId=$enrollmentId';
    if (certificationName == null || certificationName.isEmpty) return base;
    return '$base&name=${Uri.encodeComponent(certificationName)}';
  }

  static String certificateImportReviewPath(String batchId) =>
      '/certificate-import/$batchId/review';
  static String certificateImportStatusPath(String batchId) =>
      '/certificate-import/$batchId/status';
  static String certificateImportProofPath(
    String batchId,
    String fileId, {
    int page = 1,
  }) =>
      '/certificate-import/$batchId/proof/$fileId'
      '${page > 1 ? '?page=$page' : ''}';

  // Camporees helpers
  static String camporeeDetailPath(String camporeeId) =>
      '/camporee/$camporeeId';
  static String camporeeMembersPath(String camporeeId) =>
      '/camporee/$camporeeId/members';
  static String camporeeRegisterMemberPath(String camporeeId) =>
      '/camporee/$camporeeId/register';
  static String camporeeJudgeScoreEntryPath(
    int eventId,
    int clubSectionId, {
    String? eventTitle,
    String? clubLabel,
  }) {
    final base = '/camporee-events/$eventId/sections/$clubSectionId/score';
    final params = <String, String>{};
    if (eventTitle != null && eventTitle.trim().isNotEmpty) {
      params['eventTitle'] = eventTitle;
    }
    if (clubLabel != null && clubLabel.trim().isNotEmpty) {
      params['clubLabel'] = clubLabel;
    }
    if (params.isEmpty) return base;
    return '$base?${Uri(queryParameters: params).query}';
  }

  // Traslados helpers
  static String transferRequestDetail(String requestId) =>
      '/transfer/$requestId';

  // Honors evidence, completion & requirements
  static const String honorEvidence = '/honor/:honorId/evidence/:userHonorId';
  static const String honorCompletion =
      '/honor/:honorId/completion/:userHonorId';
  static const String honorRequirements =
      '/honor/:honorId/requirements/:userHonorId';

  // Helpers
  static String honorEvidencePath(String honorId, String userHonorId) =>
      '/honor/$honorId/evidence/$userHonorId';
  static String honorCompletionPath(String honorId, String userHonorId) =>
      '/honor/$honorId/completion/$userHonorId';
  static String honorRequirementsPath(
    String honorId,
    String userHonorId,
    String honorName,
  ) =>
      '/honor/$honorId/requirements/$userHonorId?name=${Uri.encodeComponent(honorName)}';

  // Informes mensuales
  static const String monthlyReports = '/monthly-reports/:enrollmentId';
  static const String monthlyReportDetail = '/monthly-report/:reportId';

  static String monthlyReportsPath(String enrollmentId) =>
      '/monthly-reports/$enrollmentId';
  static String monthlyReportDetailPath(String reportId) =>
      '/monthly-report/$reportId';

  // Asignaciones de rol
  static const String roleAssignments = '/role-assignments';

  // Coordinación — pestaña del shell principal (rama 4) y sus sub-vistas.
  // El detalle de evidencia vive fuera del shell (pantalla completa).
  static const String coordinator = '/coordinator';
  static const String coordinatorSla = '/coordinator/sla';
  static const String coordinatorEvidenceReview =
      '/coordinator/evidence-review';
  static const String coordinatorEvidenceReviewDetailRoute =
      '/coordinator/evidence-review/:type/:id';
  // Fichas de consentimiento de menores por verificar (`consent:verify`).
  static const String coordinatorConsentReview = '/coordinator/consent-review';

  // Coordinator tab routes (children of the `/coordinator` shell branch).
  static const String coordinatorClubs = '/coordinator/clubs';
  // Read-only club reports (compliance + PDFs) of the coordinator.
  static const String coordinatorReports = '/coordinator/reports';

  // Helpers para coordinación
  static String coordinatorEvidenceReviewDetail(String type, String id) =>
      '/coordinator/evidence-review/$type/$id';

  // Bandeja de notificaciones
  static const String notificationsInbox = '/notifications';

  // Miembro del Mes — historial
  static const String memberOfMonthHistory =
      '/units/member-of-month/:clubId/:sectionId';

  static String memberOfMonthHistoryPath(int clubId, int sectionId) =>
      '/units/member-of-month/$clubId/$sectionId';

  // Logros (achievements)
  static const String achievementDetail = '/achievement/:achievementId';

  // Helper
  static String achievementDetailPath(int achievementId) =>
      '/achievement/$achievementId';

  // Pagos de camporee (miembro)
  static const String camporeePayments =
      '/camporee/:camporeeId/member/:memberId/payments';

  static String camporeePaymentsPath(int camporeeId, String memberId) =>
      '/camporee/$camporeeId/member/$memberId/payments';

  // Pedidos de mercancía de camporee (no inscripción)
  static const String camporeeOrders = '/camporee/:camporeeId/orders';
  static const String camporeeOrdersCapture =
      '/camporee/:camporeeId/orders/capture';
  static const String camporeeOrdersReview =
      '/camporee/:camporeeId/orders/review';
  static const String camporeeOrderDetail = '/camporee-orders/:orderId';

  static String camporeeOrdersPath(int camporeeId, {String type = 'local'}) =>
      type == 'union'
          ? '/camporee/$camporeeId/orders?type=union'
          : '/camporee/$camporeeId/orders';

  static String camporeeOrdersCapturePath(
    int camporeeId, {
    String type = 'local',
  }) =>
      type == 'union'
          ? '/camporee/$camporeeId/orders/capture?type=union'
          : '/camporee/$camporeeId/orders/capture';

  static String camporeeOrdersReviewPath(
    int camporeeId, {
    String type = 'local',
  }) =>
      type == 'union'
          ? '/camporee/$camporeeId/orders/review?type=union'
          : '/camporee/$camporeeId/orders/review';

  static String camporeeOrderDetailPath(String orderId) =>
      '/camporee-orders/$orderId';

  static const String camporeeSupplies = '/camporee/:camporeeId/supplies';

  static String camporeeSuppliesPath(int camporeeId, {String type = 'local'}) =>
      type == 'union'
          ? '/camporee/$camporeeId/supplies?type=union'
          : '/camporee/$camporeeId/supplies';

  // Materials (orders)
  static const String homeMaterials = '/home/materials';
  static const String materialsProductDetail = '/home/materials/product/:id';
  static const String materialsCart = '/home/materials/cart';
  static const String materialsSummary = '/home/materials/summary';
  static const String materialsHistory = '/home/materials/history';
  static const String materialsOrderDetailRoute =
      '/home/materials/order/:folio';
  static const String materialsOrderPaymentRoute =
      '/home/materials/order/:folio/payment';
  static const String materialsOrderReceiptRoute =
      '/home/materials/order/:folio/receipt';

  // Helpers for materials
  static String materialsProductDetailPath(String id) =>
      '/home/materials/product/$id';

  static String materialsOrderDetail(String folioOrId) =>
      '/home/materials/order/$folioOrId';

  static String materialsOrderPayment(String folioOrId) =>
      '/home/materials/order/$folioOrId/payment';

  static String materialsOrderReceipt(String folioOrId) =>
      '/home/materials/order/$folioOrId/receipt';

  // Órdenes de pago territoriales
  static const String paymentOrders = '/payment-orders';
  static const String paymentOrderIssueInsurance =
      '/payment-orders/issue-insurance';
  static const String paymentOrderDetail = '/payment-orders/:orderId';
  static const String camporeeIssuePaymentOrder =
      '/camporee/:camporeeId/payment-orders/issue';

  static String paymentOrderDetailPath(String orderId) =>
      '/payment-orders/$orderId';

  static String camporeeIssuePaymentOrderPath(
    int camporeeId, {
    String camporeeType = 'local',
  }) =>
      camporeeType == 'union'
          ? '/camporee/$camporeeId/payment-orders/issue?type=union'
          : '/camporee/$camporeeId/payment-orders/issue';

  // Rankings
  static const String homeClubRankings = '/home/club-rankings';
  static const String homeMyRanking = '/home/my-ranking';
  static const String sectionRanking = '/section-ranking/:sectionId';
  static const String memberBreakdown = '/rankings/breakdown/:enrollmentId';

  static String sectionRankingPath(int sectionId) =>
      '/section-ranking/$sectionId';

  static String memberBreakdownPath(int enrollmentId, int yearId) =>
      '/rankings/breakdown/$enrollmentId?year_id=$yearId';

  // Mi familia: menores a cargo del tutor. Se gestionan desde el perfil propio
  // del tutor; mientras se actúa por un menor estas rutas redirigen al inicio.
  static const String family = '/family';
  static const String familyAdd = '/family/add';
  static const String familyLink = '/family/link';
  static const String familyDetail = '/family/:dependentId';

  static String familyDetailPath(String dependentId) => '/family/$dependentId';

  // Fase 3a: acceso propio de un menor y resumen para el tutor.
  static const String familyTeenLogin = '/family/:dependentId/teen-login';
  static const String familySummary = '/family/:dependentId/summary';

  static String familyTeenLoginPath(String dependentId) =>
      '/family/$dependentId/teen-login';
  static String familySummaryPath(String dependentId) =>
      '/family/$dependentId/summary';

  // Adolescente (13-17) sin tutor verificado: pantalla única del modo
  // restringido (estado, código para el tutor y cuenta atrás). Ver
  // `supervised_route_policy.dart`.
  static const String teenPendingHome = '/teen/pending';

  // Cuenta con un principal que la app no reconoce (servidor más nuevo): falla
  // cerrado en una pantalla única con «Cerrar sesión». Ver
  // `supervised_route_policy.dart`.
  static const String restrictedAccount = '/account/restricted';

  // Fase 3b: vinculación de un teléfono de menor por QR (lado del tutor).
  static const String familyPairDevice = '/family/:dependentId/pair-device';

  static String familyPairDevicePath(String dependentId) =>
      '/family/$dependentId/pair-device';

  // Fase 3b: cáscara del teléfono vinculado de un menor de 13. Ver
  // `device_route_policy.dart`. Nada de esto existe para una cuenta.
  static const String devicePair = '/device/pair';
  static const String deviceHome = '/device/home';
  static const String deviceClasses = '/device/classes';
  static const String deviceClassDetail = '/device/classes/:classId';
  static const String deviceRequirement =
      '/device/classes/:classId/requirements/:requirementId';
  static const String deviceAgenda = '/device/agenda';
  static const String deviceActivityDetail = '/device/agenda/:activityId';
  static const String deviceInbox = '/device/inbox';
  static const String deviceLegalBlock = '/device/legal';
  static const String deviceRegistrationPending =
      '/device/registration-pending';

  static String deviceClassDetailPath(int classId, {int? enrollmentId}) =>
      enrollmentId == null
          ? '/device/classes/$classId'
          : '/device/classes/$classId?enrollmentId=$enrollmentId';
  static String deviceRequirementPath(
    int classId,
    int requirementId, {
    int? enrollmentId,
  }) =>
      enrollmentId == null
          ? '/device/classes/$classId/requirements/$requirementId'
          : '/device/classes/$classId/requirements/$requirementId'
              '?enrollmentId=$enrollmentId';
  static String deviceActivityDetailPath(int activityId) =>
      '/device/agenda/$activityId';
}
