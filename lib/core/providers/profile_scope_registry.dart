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
import '../../features/teen/presentation/providers/teen_providers.dart';
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
/// La clave es la variable del provider. Los `Provider` simples son derivados y
/// se recalculan al invalidarse lo que observan; solo los que son dueños de
/// estado mutable se revisan, en [statefulPlainProviderAllowlist].
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
  // Adolescente sin tutor verificado: tutores vinculados y el código en claro
  // (solo en memoria) que se muestra al tutor.
  'supervisionStatusProvider': supervisionStatusProvider,
  'teenLinkCodeProvider': teenLinkCodeProvider,
  // Director: ids de los menores que ESTE usuario registró o cuya ficha subió
  // (aviso de cuatro ojos). Otro perfil no debe heredarlos.
  'createdMinorUserIdsProvider': createdMinorUserIdsProvider,
  'uploadedFormMinorUserIdsProvider': uploadedFormMinorUserIdsProvider,
  // Tutor: ids de los menores cuya ficha subió desde el paso 3 (copy de
  // "Solicitud enviada"). Otro perfil no debe heredarlos.
  'actingConsentFormUploadedProvider': actingConsentFormUploadedProvider,
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
  'pendingNavigationProvider':
      'destino diferido de un push tocado mientras la app carga; lo entrega o '
          'descarta el router y clearUserStateOnLogout lo borra; no guarda '
          'datos de usuario',
  'loginNoticeProvider':
      'aviso de una sola vez del login (acceso de menor revocado): se escribe '
          'al cerrar la sesión y lo limpia el siguiente intento; sin datos de '
          'usuario',
  'sessionModeProvider':
      'plomería de la sesión: AuthNotifier la escribe (arranque, emparejado, '
          '/auth/me, cierre) y el cliente HTTP la lee para no mandar nunca '
          'X-Acting-For desde un teléfono vinculado; se reinicia al cerrar '
          'sesión y no guarda datos de usuario',
  'pairingLinkProvider':
      'token de un enlace sacdia://pair recibido mientras la app arrancaba; '
          'solo en memoria, lo consume y borra PairDeviceView y '
          'clearUserStateOnLogout lo descarta; es de antes de la sesión',
  'deviceNoticeProvider':
      'aviso de una sola vez de la pantalla de vinculación (teléfono '
          'desvinculado); se escribe JUSTO al cerrar la sesión del dispositivo '
          'y debe sobrevivir a la purga de perfil; sin datos de usuario',
  'lastLoginIdentifierProvider':
      'correo o usuario tecleado en el último intento de login, solo en '
          'memoria y nunca la contraseña; es de antes de la sesión, se vacía '
          'en cuanto un login termina bien y rellena el campo si el login '
          'falla',
  'familyPromptSuppressedProvider':
      'bandera de un solo uso del tutor, la consume FamilyPromptHost; se '
          'reinicia en clearUserStateOnLogout',
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
  // Fuera de lib/features (S3: la guarda también escanea lib/core y
  // lib/providers).
  'themeNotifierProvider': 'tema claro/oscuro del dispositivo',
  'accentNotifierProvider': 'color de acento del dispositivo',
  'appBootstrapProvider':
      'compuerta de arranque, no guarda datos de usuario; logout la invalida',
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

/// `Provider` simples (no `autoDispose`) que SÍ son dueños de estado mutable
/// (un notifier, un caché, un controlador, un `onDispose`...) y que se han
/// revisado a mano, con el porqué de que no filtren datos entre perfiles.
///
/// `test/core/providers/profile_scope_registry_test.dart` falla si aparece un
/// `Provider` simple con ese perfil que no está aquí ni en
/// [profileScopedStateEntries]. Es una heurística: marca para revisión humana.
const Map<String, String> statefulPlainProviderAllowlist = {
  'actingForSessionProvider':
      'es la sesión actuar-por misma: la purga no debe tocarla; se sale con '
          'exit() y la generación sube en cada cambio',
  'actingDependentProvider':
      'derivado de la sesión: solo escucha y se recalcula, no guarda datos',
  'jsonFileCacheProvider':
      'manejador del caché en disco; su contenido por usuario se borra por '
          'prefijo al cambiar de perfil y en logout',
  'cacheRepositoryProvider':
      'repositorio de la pantalla de ajustes (medir/vaciar cachés); no guarda '
          'datos de usuario',
  'certificationDraftBoxProvider':
      'caja Hive de borradores del flujo de adultos, clave por inscripción; '
          'un dependiente nunca escribe ahí',
};
