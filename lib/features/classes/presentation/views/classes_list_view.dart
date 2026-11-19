import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_grouped_section.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';

import '../../domain/entities/progressive_class.dart';
import '../catalog/class_catalog.dart';
import '../catalog/class_catalog_providers.dart';
import '../providers/classes_providers.dart';
import '../sheets/enroll_previous_class_sheet.dart';
import '../widgets/class_card.dart';
import '../widgets/class_club_lists.dart';
import 'class_detail_with_progress_view.dart';

void _openEnrollSheet(BuildContext context) {
  showSacSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLG)),
    ),
    builder: (_) => const EnrollPreviousClassSheet(),
  );
}

/// Vista de lista de clases — tab principal del bottom nav.
///
/// Layout (top → bottom):
///   1. Barra «Mis clases» con ⋯ «Inscribir clase anterior» (solo con club
///      activo)
///   2. «CLASE ACTUAL»: una tarjeta con logo, nombre, estado y avance
///   3. Una lista agrupada por tipo de club con las clases del usuario
///   4. «EXPLORAR»: Clases por club y Certificaciones
///
/// Internamente delega el cuerpo a [ClassesListViewBody] para que también
/// pueda ser embebido en otro Scaffold sin doble Scaffold.
class ClassesListView extends ConsumerWidget {
  const ClassesListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final hasActiveClub = ref
            .watch(authNotifierProvider.select((v) => v.value))
            ?.authorization
            ?.activeGrant
            ?.sectionId !=
        null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'classes.list.title'.tr(),
        frosted: true,
        automaticallyImplyLeading: false,
        actions: [
          if (hasActiveClub)
            _OverflowMenu(onEnroll: () => _openEnrollSheet(context)),
        ],
      ),
      body: const SacFrostedVeil(
        child: ClassesListViewBody(frostedBar: true),
      ),
    );
  }
}

class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({required this.onEnroll});

  final VoidCallback onEnroll;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return PopupMenuButton<void>(
      tooltip: 'nav.more_options'.tr(),
      icon: HugeIcon(
        icon: HugeIcons.strokeRoundedMoreHorizontal,
        size: 22,
        color: c.text,
      ),
      onSelected: (_) => onEnroll(),
      itemBuilder: (_) => [
        PopupMenuItem<void>(
          height: 48,
          child: Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedBookmarkAdd02,
                size: 18,
                color: c.text,
              ),
              const SizedBox(width: 10),
              Flexible(child: Text('classes.list.enroll_tooltip'.tr())),
            ],
          ),
        ),
      ],
    );
  }
}

/// Body de la lista de clases, sin Scaffold ni AppBar propios.
/// Usar este widget cuando se embebe dentro de otro Scaffold.
class ClassesListViewBody extends ConsumerWidget {
  const ClassesListViewBody({super.key, this.frostedBar = false});

  final bool frostedBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(userClassesProvider);
    final hasActiveClub = ref
            .watch(authNotifierProvider.select((v) => v.value))
            ?.authorization
            ?.activeGrant
            ?.sectionId !=
        null;
    final listTop = (frostedBar ? SacTopBar.frostedInset(context) : 0.0) + 4;

    return classesAsync.when(
      data: (classes) => RefreshIndicator(
        color: SacAccent.of(context).color,
        edgeOffset: listTop,
        onRefresh: () => refreshClassCatalog(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(0, listTop, 0, 32),
          children: [
            if (classes.isEmpty)
              _EmptyHeader(
                hasActiveClub: hasActiveClub,
                onEnroll: () => _openEnrollSheet(context),
              )
            else ...[
              _CurrentSection(currentClass: currentClassOf(classes)),
              _ClubLists(enrolled: classes),
            ],
            const _ExploreSection(),
          ],
        ),
      ),
      loading: () => const Center(child: SacLoading()),
      error: (error, stack) => SacErrorState(
        title: 'classes.list.error_loading'.tr(),
        message: userErrorMessage(error),
        onRetry: () => ref.invalidate(userClassesProvider),
      ),
    );
  }
}

// ── Clase actual ──────────────────────────────────────────────────────────────

class _CurrentSection extends ConsumerWidget {
  const _CurrentSection({required this.currentClass});

  final ProgressiveClass? currentClass;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = currentClass;
    if (current == null) return const SizedBox.shrink();

    final progress = ref
            .watch(
              classWithProgressProvider(ClassProgressQuery.fromClass(current)),
            )
            .whenOrNull(data: (cwp) => cwp.completionRatio) ??
        0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'classes.list.section_current'.tr().toUpperCase(),
              style: TextStyle(
                fontSize: SacFontSize.labelSmall,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: context.sac.textTertiary,
              ),
            ),
          ),
          ClassCard(
            progressiveClass: current,
            progress: progress,
            onTap: () => Navigator.push(
              context,
              SacSharedAxisRoute(
                builder: (_) => ClassDetailWithProgressView(
                  classId: current.id,
                  enrollmentId: current.enrollmentId,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Listas por club ───────────────────────────────────────────────────────────

/// Same data as «Clases por club» (`classCatalogProvider`). While it loads or
/// if it fails the lists are simply absent; the current class and «Explorar»
/// still work and pull-to-refresh retries it.
class _ClubLists extends ConsumerWidget {
  const _ClubLists({required this.enrolled});

  final List<ProgressiveClass> enrolled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(classCatalogProvider).value;
    if (sections == null) return const SizedBox.shrink();
    return ClassClubLists(sections: sections, enrolled: enrolled);
  }
}

// ── Explorar ──────────────────────────────────────────────────────────────────

class _ExploreSection extends StatelessWidget {
  const _ExploreSection();

  @override
  Widget build(BuildContext context) {
    return SacGroupedSection(
      label: 'classes.list.section_explore'.tr(),
      count: 0,
      action: const SizedBox.shrink(),
      children: [
        _ExploreRow(
          icon: HugeIcons.strokeRoundedLeftToRightListBullet,
          title: 'classes.list.catalog_chip_title'.tr(),
          subtitle: 'classes.list.catalog_chip_subtitle'.tr(),
          onTap: () => context.push(RouteNames.homeClassesCatalog),
        ),
        _ExploreRow(
          icon: HugeIcons.strokeRoundedCertificate01,
          title: 'classes.list.certifications_chip_title'.tr(),
          subtitle: 'classes.list.certifications_chip_subtitle'.tr(),
          onTap: () => context.push(RouteNames.homeCertifications),
        ),
      ],
    );
  }
}

class _ExploreRow extends StatelessWidget {
  const _ExploreRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final HugeIconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context).color;
    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label: '$title. $subtitle',
      onTap: onTap,
      child: SacInkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  ),
                  child: HugeIcon(icon: icon, size: 20, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: SacFontSize.titleMedium,
                          fontWeight: FontWeight.w600,
                          color: c.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: SacFontSize.bodySmall,
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  size: 18,
                  color: c.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty ─────────────────────────────────────────────────────────────────────

class _EmptyHeader extends StatelessWidget {
  const _EmptyHeader({required this.hasActiveClub, required this.onEnroll});

  final bool hasActiveClub;
  final VoidCallback onEnroll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        children: [
          SacEmptyState(
            icon: HugeIcons.strokeRoundedSchool,
            title: 'classes.list.empty'.tr(),
          ),
          if (hasActiveClub) ...[
            const SizedBox(height: 24),
            SacButton.primary(
              text: 'classes.list.enroll_cta'.tr(),
              icon: HugeIcons.strokeRoundedAdd01,
              onPressed: onEnroll,
            ),
          ],
        ],
      ),
    );
  }
}
