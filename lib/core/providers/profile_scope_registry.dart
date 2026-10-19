import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/achievements/presentation/providers/achievements_providers.dart';
import '../../features/activities/presentation/providers/activities_providers.dart';
import '../../features/certifications/presentation/providers/certifications_providers.dart';
import '../../features/classes/presentation/providers/classes_providers.dart';
import '../../features/club/presentation/providers/club_providers.dart';
import '../../features/dashboard/presentation/providers/dashboard_providers.dart';
import '../../features/enrollment/presentation/providers/enrollment_providers.dart';
import '../../features/evidence_folder/presentation/providers/evidence_folder_providers.dart';
import '../../features/honors/presentation/providers/honors_providers.dart';
import '../../features/master_honors/presentation/providers/master_honor_modal_queue_provider.dart';
import '../../features/master_honors/presentation/providers/master_honors_providers.dart';
import '../../features/members/presentation/providers/members_providers.dart';
import '../../features/monthly_reports/presentation/providers/monthly_reports_providers.dart';
import '../../features/notifications/presentation/providers/notifications_providers.dart';
import '../../features/notifications/presentation/providers/unread_notifications_count_provider.dart';
import '../../features/post_registration/presentation/providers/post_registration_providers.dart';
import '../../features/rankings/presentation/providers/annual_ranking_progress_provider.dart';
import '../../features/rankings/presentation/providers/club_ranking_provider.dart';
import '../../features/rankings/presentation/providers/member_breakdown_provider.dart';
import '../../features/rankings/presentation/providers/my_ranking_provider.dart';
import '../../features/rankings/presentation/providers/section_ranking_provider.dart';
import '../../features/qr/presentation/providers/qr_member_token_provider.dart';
import '../../features/support/presentation/providers/support_providers.dart';
import '../../features/units/presentation/providers/units_providers.dart';
import '../../features/validation/presentation/providers/validation_providers.dart';
import '../../features/virtual_card/presentation/providers/virtual_card_providers.dart';
import 'app_bootstrap_provider.dart';

/// Registro de providers con estado de un perfil concreto (FP-48, FP-52).
///
/// Un provider `autoDispose` + `keepAlive()` sobrevive al cambio de pantalla y
/// al cambio de perfil: si no se invalida explícitamente al pasar de la tutora
/// a Ana (o de Ana a Luis), el siguiente perfil vería sus datos. Por eso TODO
/// `keepAlive()` bajo `lib/features/**/providers/*.dart` debe estar en uno de
/// dos sitios, y `test/core/providers/profile_scope_registry_test.dart` falla
/// si aparece uno nuevo en ninguno:
///
///   1. [profileScopedKeepAliveEntries]: se invalida en cada cambio de perfil.
///   2. [catalogKeepAliveAllowlist]: catálogo/estado transitorio que NO depende
///      de quién pregunta.
///
/// La clave es el símbolo que llama a `keepAlive()` en el código fuente: la
/// variable del provider o, cuando se llama dentro de un notifier, el nombre de
/// su clase. Es lo que lee el test al escanear los archivos.
final Map<String, ProviderOrFamily> profileScopedKeepAliveEntries = {
  // Logros
  'achievementsCatalogProvider': achievementsCatalogProvider,
  'userAchievementsProvider': userAchievementsProvider,
  'achievementCategoriesProvider': achievementCategoriesProvider,
  // Actividades y club
  'clubActivitiesProvider': clubActivitiesProvider,
  'activityDetailProvider': activityDetailProvider,
  'currentClubSectionProvider': currentClubSectionProvider,
  // Certificaciones, validación y carpeta de evidencias
  'certificationsProvider': certificationsProvider,
  'eligibilityProvider': eligibilityProvider,
  'evidenceFolderProvider': evidenceFolderProvider,
  // Clases
  'userClassesProvider': userClassesProvider,
  'classesByClubTypeProvider': classesByClubTypeProvider,
  'allClassesProvider': allClassesProvider,
  // Especialidades
  'honorCategoriesProvider': honorCategoriesProvider,
  'userHonorsProvider': userHonorsProvider,
  'honorsGroupedByCategoryProvider': honorsGroupedByCategoryProvider,
  'allHonorsProvider': allHonorsProvider,
  'userHonorProgressProvider': userHonorProgressProvider,
  'userMasterHonorsProvider': userMasterHonorsProvider,
  'userMasterHonorRoadmapProvider': userMasterHonorRoadmapProvider,
  // Informes mensuales
  'monthlyReportPdfProvider': monthlyReportPdfProvider,
  // Post-registro (el keepAlive se llama dentro del notifier)
  'CompletionStatusNotifier': completionStatusProvider,
  // Rankings: la respuesta depende de quién pregunta (RBAC del servidor)
  'annualRankingProgressProvider': annualRankingProgressProvider,
  'clubRankingsProvider': clubRankingsProvider,
  'memberBreakdownProvider': memberBreakdownProvider,
  'myRankingProvider': myRankingProvider,
  'sectionMembersProvider': sectionMembersProvider,
  // Credencial virtual
  'virtualCardFetcherProvider': virtualCardFetcherProvider,
};

/// `keepAlive()` que NO depende del perfil: catálogos estables durante la
/// sesión y estado transitorio de formularios de camporee.
///
/// Mismo criterio de clave que [profileScopedKeepAliveEntries].
const Set<String> catalogKeepAliveAllowlist = {
  // Materiales: catálogo igual para todos.
  'configProvider',
  'categoriesProvider',
  'programsProvider',
  // Camporees: el keepAlive solo cubre el envío en curso (se cierra al acabar).
  'RegisterCamporeeSectionNotifier',
  // Pedidos de camporee: igual, solo mientras dura el envío.
  'CamporeeOrderDraftNotifier',
};

/// Providers SIN `autoDispose` con estado que depende de quién es el perfil
/// activo (FP-48, FP-52).
///
/// Un provider sin `autoDispose` vive lo que vive la app: aunque no llame a
/// `keepAlive()`, conserva su estado al pasar de la tutora a Ana. Por eso TODO
/// `StateProvider`/`Notifier`/`AsyncNotifier`/`FutureProvider`/... sin
/// `autoDispose` bajo `lib/features/**` debe estar en uno de dos sitios, y
/// `test/core/providers/profile_scope_registry_test.dart` falla si aparece uno
/// nuevo en ninguno:
///
///   1. [profileScopedStateEntries]: se invalida en cada cambio de perfil.
///   2. [nonAutoDisposeAllowlist]: estado global (dispositivo, catálogo,
///      plomería de la sesión) con el motivo por el que no depende del perfil.
///
/// La clave es la variable del provider. Los `Provider` simples no se vigilan:
/// son derivados y se recalculan al invalidarse lo que observan.
final Map<String, ProviderOrFamily> profileScopedStateEntries = {
  'dashboardNotifierProvider': dashboardNotifierProvider,
  'clubContextProvider': clubContextProvider,
  'currentEnrollmentProvider': currentEnrollmentProvider,
  'notificationsInboxProvider': notificationsInboxProvider,
  // Contador de no leídas: `Notifier` sin autoDispose; invalidar lo deja en 0.
  'unreadNotificationsCountProvider': unreadNotificationsCountProvider,
  // Especialidades: copia local del UserHonor cuyo modo de cumplimiento se
  // cambió; si sobrevive, el perfil siguiente la ve como su inscripción (C2).
  'honorCompletionModeOverrideProvider': honorCompletionModeOverrideProvider,
  'masterHonorModalQueueProvider': masterHonorModalQueueProvider,
  // Token QR del miembro: con 429/sin red la credencial lo usa de respaldo y
  // mostraría el QR de otra persona (W3).
  'qrMemberTokenProvider': qrMemberTokenProvider,
  'unitsNotifierProvider': unitsNotifierProvider,
  'virtualCardRateLimitNoticeProvider': virtualCardRateLimitNoticeProvider,
  'supportReportSubmitProvider': supportReportSubmitProvider,
};

/// Estado sin `autoDispose` que NO depende del perfil, con el porqué.
///
/// Mismo criterio de clave que [profileScopedStateEntries]. Añadir aquí algo
/// que sí guarde datos del usuario reintroduce la fuga de FP-48.
const Map<String, String> nonAutoDisposeAllowlist = {
  // Plomería de la sesión: la gestiona AuthNotifier a mano.
  'authNotifierProvider':
      'es el perfil mismo: switchProfile lo recarga; la purga no debe tocarlo',
  'guardianUserProvider':
      'foto del tutor durante el modo actuar-por; se borra al salir y al logout',
  'actingNoticeProvider': 'aviso de una sola vez, se limpia al salir y logout',
  // Flujos previos a la sesión o de un solo uso.
  'socialSignInInFlightProvider':
      'bandera de la pantalla de login, sin sesión de por medio',
  'familyPromptSuppressedProvider':
      'bandera de un solo uso del tutor, la consume FamilyPromptHost',
  // Preferencias del dispositivo.
  'welcomeCarouselSeenProvider': 'bandera del dispositivo, no de la cuenta',
  'accessibilityProvider': 'preferencias de accesibilidad del dispositivo',
  'biometricProvider': 'ajuste y desbloqueo biométrico del dispositivo',
  'biometricCapabilityProvider': 'capacidad del hardware, igual para todos',
  // Catálogos y contenido estático.
  'categoriesProvider': 'catálogo de materiales, igual para todos',
  'configProvider': 'configuración de materiales, igual para todos',
  'programsProvider': 'catálogo de programas, igual para todos',
  'deviceReportInfoProvider': 'datos del dispositivo para reportes',
  'faqItemsProvider': 'preguntas frecuentes estáticas',
  'faqSearchQueryProvider':
      'texto de búsqueda de la pantalla, sin datos de perfil',
};

/// Todo lo que se invalida al cambiar de perfil (entrar, salir o cambiar de
/// dependiente): los providers de usuario de [userSpecificProviders], los
/// `keepAlive` por perfil y el estado sin `autoDispose` de
/// [profileScopedStateEntries].
final List<ProviderOrFamily> profileScopedProviders = <ProviderOrFamily>{
  ...userSpecificProviders,
  ...profileScopedKeepAliveEntries.values,
  ...profileScopedStateEntries.values,
}.toList(growable: false);
