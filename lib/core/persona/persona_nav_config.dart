import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/persona/nav_slot.dart';
import 'package:sacdia_app/core/persona/persona.dart';

/// Declarative nav-slot config for every [Persona].
///
/// Each persona maps to exactly 5 [NavSlot]s. The slots define the bottom
/// navigation bar (or NavigationRail on tablets).
///
/// IMPORTANT: [NavSlot.branchIndex] values reference the MAIN shell's
/// [StatefulShellRoute.indexedStack] branch list (branches 0–17). They MUST
/// NOT be renumbered; stability is required for deep-link and push-notification
/// routing (NFR-5).
///
/// The Activities slot MUST appear in every persona's config (FR-8, NFR-2).
const Map<Persona, List<NavSlot>> personaNavConfig = {
  // ── Miembro ────────────────────────────────────────────────────────────────
  // Nav: Dashboard | Clases | Actividades | Ranking | Perfil
  Persona.miembro: [
    NavSlot(
      icon: HugeIcons.strokeRoundedHome01,
      labelKey: 'nav.dashboard',
      branchIndex: 0,
      route: RouteNames.homeDashboard,
    ),
    NavSlot(
      icon: HugeIcons.strokeRoundedSchool,
      labelKey: 'nav.classes',
      branchIndex: 1,
      route: RouteNames.homeClasses,
    ),
    NavSlot(
      icon: HugeIcons.strokeRoundedCalendar01,
      labelKey: 'nav.activities',
      branchIndex: 2,
      route: RouteNames.homeActivities,
      badgeSource: NavBadgeSource.activities,
    ),
    NavSlot(
      icon: HugeIcons.strokeRoundedRanking,
      labelKey: 'nav.ranking',
      branchIndex: 17,
      route: RouteNames.homeMyRanking,
    ),
    NavSlot(
      icon: HugeIcons.strokeRoundedUser,
      labelKey: 'nav.profile',
      branchIndex: 3,
      route: RouteNames.homeProfile,
    ),
  ],

  // ── Consejero ──────────────────────────────────────────────────────────────
  // Nav: Mi Unidad | Clases (agrupadas) | Miembros | Actividades | Perfil
  Persona.consejero: [
    NavSlot(
      icon: HugeIcons.strokeRoundedCompass01,
      labelKey: 'nav.my_unit',
      branchIndex: 8,
      route: RouteNames.homeUnits,
      badgeSource: NavBadgeSource.unit,
    ),
    NavSlot(
      icon: HugeIcons.strokeRoundedSchool,
      labelKey: 'nav.classes',
      branchIndex: 9,
      route: RouteNames.homeGroupedClass,
    ),
    NavSlot(
      icon: HugeIcons.strokeRoundedUserGroup,
      labelKey: 'nav.members',
      branchIndex: 4,
      route: RouteNames.homeMembers,
      badgeSource: NavBadgeSource.members,
    ),
    NavSlot(
      icon: HugeIcons.strokeRoundedCalendar01,
      labelKey: 'nav.activities',
      branchIndex: 2,
      route: RouteNames.homeActivities,
      badgeSource: NavBadgeSource.activities,
    ),
    NavSlot(
      icon: HugeIcons.strokeRoundedUser,
      labelKey: 'nav.profile',
      branchIndex: 3,
      route: RouteNames.homeProfile,
    ),
  ],

  // ── Director ───────────────────────────────────────────────────────────────
  // Nav: Miembros | Club | Finanzas | Actividades | Perfil
  Persona.director: [
    NavSlot(
      icon: HugeIcons.strokeRoundedUserGroup,
      labelKey: 'nav.members',
      branchIndex: 4,
      route: RouteNames.homeMembers,
      badgeSource: NavBadgeSource.members,
    ),
    NavSlot(
      icon: HugeIcons.strokeRoundedBuilding01,
      labelKey: 'nav.club',
      branchIndex: 5,
      route: RouteNames.homeClub,
    ),
    NavSlot(
      icon: HugeIcons.strokeRoundedCreditCard,
      labelKey: 'nav.finances',
      branchIndex: 7,
      route: RouteNames.homeFinances,
      badgeSource: NavBadgeSource.finances,
    ),
    NavSlot(
      icon: HugeIcons.strokeRoundedCalendar01,
      labelKey: 'nav.activities',
      branchIndex: 2,
      route: RouteNames.homeActivities,
      badgeSource: NavBadgeSource.activities,
    ),
    NavSlot(
      icon: HugeIcons.strokeRoundedUser,
      labelKey: 'nav.profile',
      branchIndex: 3,
      route: RouteNames.homeProfile,
    ),
  ],

  // ── Tesorero ───────────────────────────────────────────────────────────────
  // Nav: Finanzas | Seguros | Club | Actividades | Perfil
  Persona.tesorero: [
    NavSlot(
      icon: HugeIcons.strokeRoundedCreditCard,
      labelKey: 'nav.finances',
      branchIndex: 7,
      route: RouteNames.homeFinances,
      badgeSource: NavBadgeSource.finances,
    ),
    NavSlot(
      icon: HugeIcons.strokeRoundedShield01,
      labelKey: 'nav.insurance',
      branchIndex: 10,
      route: RouteNames.homeInsurance,
    ),
    NavSlot(
      icon: HugeIcons.strokeRoundedBuilding01,
      labelKey: 'nav.club',
      branchIndex: 5,
      route: RouteNames.homeClub,
    ),
    NavSlot(
      icon: HugeIcons.strokeRoundedCalendar01,
      labelKey: 'nav.activities',
      branchIndex: 2,
      route: RouteNames.homeActivities,
      badgeSource: NavBadgeSource.activities,
    ),
    NavSlot(
      icon: HugeIcons.strokeRoundedUser,
      labelKey: 'nav.profile',
      branchIndex: 3,
      route: RouteNames.homeProfile,
    ),
  ],

  // ── Coordinador ────────────────────────────────────────────────────────────
  // Nav: Hub | Clubes | Reportes | Actividades | Perfil
  // NOTE: Coordinador uses a SEPARATE StatefulShellRoute (PR-4). The
  // branchIndex values here reference the COORDINATOR shell's branch list
  // (0–4), NOT the main shell's branches (0–17). They are scoped separately.
  Persona.coordinador: [
    NavSlot(
      icon: HugeIcons.strokeRoundedAnalytics01,
      labelKey: 'nav.hub',
      branchIndex: 0,
      route: RouteNames.coordinator,
      badgeSource: NavBadgeSource.hub,
    ),
    NavSlot(
      icon: HugeIcons.strokeRoundedBuilding01,
      labelKey: 'nav.clubs',
      branchIndex: 1,
      route: RouteNames.coordinator,
    ),
    NavSlot(
      icon: HugeIcons.strokeRoundedFiles01,
      labelKey: 'nav.reports',
      branchIndex: 2,
      route: RouteNames.coordinator,
    ),
    NavSlot(
      icon: HugeIcons.strokeRoundedCalendar01,
      labelKey: 'nav.activities',
      branchIndex: 3,
      route: RouteNames.homeActivities,
      badgeSource: NavBadgeSource.activities,
    ),
    NavSlot(
      icon: HugeIcons.strokeRoundedUser,
      labelKey: 'nav.profile',
      branchIndex: 4,
      route: RouteNames.homeProfile,
    ),
  ],
};
