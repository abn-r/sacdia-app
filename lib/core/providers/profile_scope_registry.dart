import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/achievements/presentation/providers/achievements_providers.dart';
import '../../features/activities/presentation/providers/activities_providers.dart';
import '../../features/certifications/presentation/providers/certifications_providers.dart';
import '../../features/classes/presentation/providers/classes_providers.dart';
import '../../features/club/presentation/providers/club_providers.dart';
import '../../features/evidence_folder/presentation/providers/evidence_folder_providers.dart';
import '../../features/honors/presentation/providers/honors_providers.dart';
import '../../features/master_honors/presentation/providers/master_honors_providers.dart';
import '../../features/monthly_reports/presentation/providers/monthly_reports_providers.dart';
import '../../features/notifications/presentation/providers/unread_notifications_count_provider.dart';
import '../../features/post_registration/presentation/providers/post_registration_providers.dart';
import '../../features/rankings/presentation/providers/annual_ranking_progress_provider.dart';
import '../../features/rankings/presentation/providers/club_ranking_provider.dart';
import '../../features/rankings/presentation/providers/member_breakdown_provider.dart';
import '../../features/rankings/presentation/providers/my_ranking_provider.dart';
import '../../features/rankings/presentation/providers/section_ranking_provider.dart';
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

/// Providers por perfil que NO llaman a `keepAlive()` pero igual sobreviven
/// (no son `autoDispose`) y guardan estado del usuario.
final List<ProviderOrFamily> _otherProfileScopedProviders = [
  // Contador de no leídas: `Notifier` sin autoDispose; invalidar lo deja en 0.
  unreadNotificationsCountProvider,
];

/// Todo lo que se invalida al cambiar de perfil (entrar, salir o cambiar de
/// dependiente): los providers de usuario de [userSpecificProviders] más los
/// `keepAlive` por perfil.
final List<ProviderOrFamily> profileScopedProviders = <ProviderOrFamily>{
  ...userSpecificProviders,
  ...profileScopedKeepAliveEntries.values,
  ..._otherProfileScopedProviders,
}.toList(growable: false);
