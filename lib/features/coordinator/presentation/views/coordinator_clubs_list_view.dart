import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/coordinator_club.dart';
import 'package:sacdia_app/features/coordinator/presentation/providers/coordinator_providers.dart';

/// Vista principal de la rama Clubes del coordinador.
///
/// Reemplaza el placeholder [CamporeeApprovalsView] que ocupaba el
/// branchIndex=1 del StatefulShellRoute de coordinación (PR-4 / FR-2).
///
/// Muestra todos los clubs accesibles al coordinador con búsqueda por nombre
/// y navega al detalle de club al tocar una tarjeta.
class CoordinatorClubsListView extends ConsumerWidget {
  const CoordinatorClubsListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final hPad = Responsive.horizontalPadding(context);
    final clubsAsync = ref.watch(coordinatorClubsProvider);

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            _ClubsHeader(hPad: hPad),

            // ── Search bar ────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 12),
              child: const _ClubSearchBar(),
            ),

            // ── Content ───────────────────────────────────────────────────
            Expanded(
              child: clubsAsync.when(
                loading: () => _ClubsLoadingSkeleton(hPad: hPad),
                error: (error, _) => _ClubsErrorState(
                  message: error.toString(),
                  onRetry: () => ref.invalidate(coordinatorClubsRawProvider),
                ),
                data: (clubs) => clubs.isEmpty
                    ? const _ClubsEmptyState()
                    : _ClubsList(clubs: clubs, hPad: hPad),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _ClubsHeader extends ConsumerWidget {
  final double hPad;
  const _ClubsHeader({required this.hPad});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final rawAsync = ref.watch(coordinatorClubsRawProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const HugeIcon(
              icon: HugeIcons.strokeRoundedBuilding04,
              size: 22,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'coordinator.clubs.title'.tr(),
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: c.text, fontWeight: FontWeight.w700),
            ),
          ),
          // Refresh button (44dp touch target)
          SizedBox(
            width: 44,
            height: 44,
            child: Material(
              color: c.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: c.border),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: rawAsync.isLoading
                    ? null
                    : () => ref.invalidate(coordinatorClubsRawProvider),
                child: Semantics(
                  label: 'common.retry'.tr(),
                  button: true,
                  child: Center(
                    child: rawAsync.isLoading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: c.textTertiary,
                            ),
                          )
                        : HugeIcon(
                            icon: HugeIcons.strokeRoundedRefresh,
                            color: c.textTertiary,
                            size: 18,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

class _ClubSearchBar extends ConsumerStatefulWidget {
  const _ClubSearchBar();

  @override
  ConsumerState<_ClubSearchBar> createState() => _ClubSearchBarState();
}

class _ClubSearchBarState extends ConsumerState<_ClubSearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: TextField(
        controller: _controller,
        onChanged: (value) {
          ref.read(coordinatorClubSearchProvider.notifier).state = value;
        },
        style: TextStyle(fontSize: 14, color: c.text),
        decoration: InputDecoration(
          hintText: 'coordinator.clubs.search_hint'.tr(),
          hintStyle: TextStyle(color: c.textTertiary, fontSize: 14),
          prefixIcon: HugeIcon(
            icon: HugeIcons.strokeRoundedSearch01,
            color: c.textTertiary,
            size: 20,
          ),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedCancel01,
                    color: c.textTertiary,
                    size: 18,
                  ),
                  onPressed: () {
                    _controller.clear();
                    ref.read(coordinatorClubSearchProvider.notifier).state = '';
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        ),
      ),
    );
  }
}

// ── Clubs list ────────────────────────────────────────────────────────────────

class _ClubsList extends StatelessWidget {
  final List<CoordinatorClub> clubs;
  final double hPad;

  const _ClubsList({required this.clubs, required this.hPad});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        // Handled by invalidate in header — pull-to-refresh triggers same path
      },
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 24),
        itemCount: clubs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          return StaggeredListItem(
            index: index,
            initialDelay: const Duration(milliseconds: 20),
            child: _ClubCard(club: clubs[index]),
          );
        },
      ),
    );
  }
}

// ── Club card ─────────────────────────────────────────────────────────────────

class _ClubCard extends StatelessWidget {
  final CoordinatorClub club;

  const _ClubCard({required this.club});

  static final _kRadius = BorderRadius.circular(16);

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    // ClubModel only carries name and localFieldId — no clubTypeName.
    // We fall back to AppColors.primary until the backend exposes type info.
    // GAP: coordinator list endpoint does not return club type — documented.
    final accentColor = AppColors.primary;

    return Semantics(
      label: club.name,
      button: true,
      child: Material(
        color: c.surface,
        borderRadius: _kRadius,
        child: InkWell(
          borderRadius: _kRadius,
          onTap: () => _openClubDetail(context, club),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: _kRadius,
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                // ── Club type icon badge ──────────────────────────────────
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedBuilding04,
                      size: 22,
                      color: accentColor,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // ── Club info ─────────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        club.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: c.text,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'coordinator.clubs.field_id_label'
                            .tr(namedArgs: {'id': '${club.localFieldId}'}),
                        style: TextStyle(
                          fontSize: 12,
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // ── Chevron ───────────────────────────────────────────────
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

  void _openClubDetail(BuildContext context, CoordinatorClub club) {
    // Navigate to club detail route using the club's numeric id as string.
    // RouteNames.clubDetailPath expects a String clubId (UUID or numeric).
    context.push(RouteNames.clubDetailPath(club.id.toString()));
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────

class _ClubsLoadingSkeleton extends StatelessWidget {
  final double hPad;
  const _ClubsLoadingSkeleton({required this.hPad});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 24),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => Container(
        height: 80,
        decoration: BoxDecoration(
          color: c.border,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _ClubsEmptyState extends StatelessWidget {
  const _ClubsEmptyState();

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedBuilding04,
              size: 56,
              color: c.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'coordinator.clubs.empty_title'.tr(),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'coordinator.clubs.empty_subtitle'.tr(),
              style: TextStyle(fontSize: 14, color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ClubsErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _ClubsErrorState({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedAlert02,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              'coordinator.clubs.error_load'.tr(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(fontSize: 13, color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              SacButton.primary(
                text: 'common.retry'.tr(),
                icon: HugeIcons.strokeRoundedRefresh,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
