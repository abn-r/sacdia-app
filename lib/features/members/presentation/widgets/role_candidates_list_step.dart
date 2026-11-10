import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/fixed_input_icon_slot.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_filter_chip.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';

import '../../domain/entities/role_candidate.dart';
import '../providers/members_providers.dart';
import '../providers/role_candidates_providers.dart';
import '../utils/role_candidate_labels.dart';
import 'join_request_group.dart';
import 'role_candidate_row.dart';
import 'role_candidates_skeleton.dart';
import 'role_slot_pills.dart';

/// Filters shown as chips. «all» exists in the API but not in the UI.
const _chipFilters = [
  RoleCandidatesFilter.available,
  RoleCandidatesFilter.withRole,
  RoleCandidatesFilter.notEnrolled,
];

/// How long the user must stop typing before the search is sent.
const Duration kRoleCandidatesSearchDebounce = Duration(milliseconds: 350);

/// Step 1 of «Agregar directivo»: slot pills, search, filter chips and the
/// grouped list of Guías Mayores. Stays mounted while the later steps are open
/// so the search, filter and scroll survive going back.
class RoleCandidatesListStep extends ConsumerStatefulWidget {
  const RoleCandidatesListStep({
    super.key,
    required this.clubContext,
    required this.onSelect,
  });

  final ClubContext clubContext;

  /// A person with at least one allowed role was tapped. Gets the loaded state
  /// so the next step can read the slots.
  final void Function(RoleCandidate candidate, RoleCandidatesState state)
      onSelect;

  @override
  ConsumerState<RoleCandidatesListStep> createState() =>
      _RoleCandidatesListStepState();
}

class _RoleCandidatesListStepState
    extends ConsumerState<RoleCandidatesListStep> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  RoleCandidatesFilter _filter = RoleCandidatesFilter.available;
  String _search = '';

  /// Last loaded data: keeps the pills and the chip counts on screen while a
  /// new filter or search is loading.
  RoleCandidatesState? _lastLoaded;

  RoleCandidatesQuery get _query => RoleCandidatesQuery(
        clubId: widget.clubContext.clubId,
        sectionId: widget.clubContext.sectionId,
        filter: _filter,
        search: _search,
      );

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController
      ..removeListener(_maybeLoadMore)
      ..dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter > 320) return;
    ref.read(roleCandidatesProvider(_query).notifier).loadMore();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(kRoleCandidatesSearchDebounce, () {
      if (!mounted || value.trim() == _search) return;
      setState(() => _search = value.trim());
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    if (_search.isNotEmpty) setState(() => _search = '');
  }

  void _setFilter(RoleCandidatesFilter filter) {
    if (filter == _filter) return;
    setState(() => _filter = filter);
  }

  @override
  Widget build(BuildContext context) {
    final query = _query;
    final async = ref.watch(roleCandidatesProvider(query));
    ref.listen(roleCandidatesProvider(query), (_, next) {
      final value = next.value;
      if (value != null) _lastLoaded = value;
    });
    final shown = async.value ?? _lastLoaded;

    return Column(
      children: [
        if (shown != null && shown.slots.isNotEmpty) ...[
          RoleSlotPills(slots: shown.slots),
          const SizedBox(height: 12),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _SearchField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            onClear: _clearSearch,
          ),
        ),
        SizedBox(
          height: SacFilterChip.barHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _chipFilters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final filter = _chipFilters[i];
              return Center(
                child: SacFilterChip(
                  label: roleCandidateFilterLabel(filter),
                  selected: filter == _filter,
                  count: shown?.counts.of(filter),
                  onTap: () => _setFilter(filter),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const RoleCandidatesSkeleton(),
            error: (error, _) => _ErrorBody(
              error: error,
              onRetry: () => ref.invalidate(roleCandidatesProvider(query)),
            ),
            data: (state) => _Body(
              state: state,
              query: query,
              hasSearch: _search.isNotEmpty,
              sectionId: widget.clubContext.sectionId,
              controller: _scrollController,
              onSelect: (c) => widget.onSelect(c, state),
              onRefresh: () async {
                try {
                  ref.invalidate(roleCandidatesProvider(query));
                  await ref.read(roleCandidatesProvider(query).future);
                } catch (_) {}
              },
              onLoadMore: () =>
                  ref.read(roleCandidatesProvider(query).notifier).loadMore(),
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        border: Border.all(color: c.border),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: TextStyle(fontSize: SacFontSize.titleSmall, color: c.text),
        decoration: InputDecoration(
          hintText: 'members.role_candidates.search_hint'.tr(),
          hintStyle: TextStyle(
            color: c.textTertiary,
            fontSize: SacFontSize.titleSmall,
          ),
          prefixIconConstraints: FixedInputIconSlot.constraints,
          prefixIcon: FixedInputIconSlot(
            icon: HugeIcons.strokeRoundedSearch01,
            color: c.textTertiary,
            iconSize: 20,
          ),
          suffixIconConstraints: FixedInputIconSlot.constraints,
          suffixIcon: ListenableBuilder(
            listenable: controller,
            builder: (_, __) => controller.text.isEmpty
                ? const SizedBox.shrink()
                : Semantics(
                    button: true,
                    label: 'common.clear'.tr(),
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onClear,
                      child: FixedInputIconSlot(
                        icon: HugeIcons.strokeRoundedCancel01,
                        color: c.textTertiary,
                        iconSize: 18,
                      ),
                    ),
                  ),
          ),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SacErrorState(
      title: 'members.role_candidates.error_title'.tr(),
      message: userErrorMessage(error),
      onRetry: onRetry,
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    required this.query,
    required this.hasSearch,
    required this.sectionId,
    required this.controller,
    required this.onSelect,
    required this.onRefresh,
    required this.onLoadMore,
  });

  final RoleCandidatesState state;
  final RoleCandidatesQuery query;
  final bool hasSearch;
  final int sectionId;
  final ScrollController controller;
  final void Function(RoleCandidate) onSelect;
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final accent = SacAccent.of(context);
    // The server says the club has no Guías Mayores section: nothing to retry.
    if (state.section?.hasGmSection == false) {
      return SacEmptyState(
        icon: HugeIcons.strokeRoundedUserGroup,
        title: 'members.role_candidates.no_gm_section_title'.tr(),
        body: 'members.role_candidates.no_gm_section_body'.tr(),
      );
    }
    if (state.items.isEmpty) {
      return RefreshIndicator(
        color: accent.color,
        onRefresh: onRefresh,
        child: SacEmptyState(
          scrollable: true,
          icon: hasSearch
              ? HugeIcons.strokeRoundedSearch01
              : HugeIcons.strokeRoundedUserGroup,
          title: hasSearch
              ? 'members.role_candidates.no_results_title'.tr()
              : 'members.role_candidates.empty_title'.tr(),
          body: hasSearch
              ? 'members.role_candidates.no_results_body'.tr()
              : switch (query.filter) {
                  RoleCandidatesFilter.withRole =>
                    'members.role_candidates.empty_with_role'.tr(),
                  RoleCandidatesFilter.notEnrolled =>
                    'members.role_candidates.empty_not_enrolled'.tr(),
                  _ => 'members.role_candidates.empty_available'.tr(),
                },
        ),
      );
    }

    final c = context.sac;
    final year = state.section?.yearName;
    final groups = [
      for (final group in RoleCandidateGroup.values)
        (
          group: group,
          items: [
            for (final i in state.items)
              if (i.group == group) i
          ],
        ),
    ].where((g) => g.items.isNotEmpty).toList();

    return RefreshIndicator(
      color: accent.color,
      onRefresh: onRefresh,
      child: ListView(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          for (var g = 0; g < groups.length; g++) ...[
            if (g > 0) const SizedBox(height: 20),
            JoinRequestGroupSection(
              title: roleCandidateGroupTitle(groups[g].group, year: year),
              // The server count covers every page; never show less than
              // what is already on screen.
              count: [
                state.counts.of(groups[g].group.filter),
                groups[g].items.length,
              ].reduce((a, b) => a > b ? a : b),
              dotColor: switch (groups[g].group) {
                RoleCandidateGroup.available => accent.color,
                RoleCandidateGroup.withRole => c.textTertiary,
                RoleCandidateGroup.notEnrolled => c.warning,
              },
              children: [
                for (final candidate in groups[g].items)
                  RoleCandidateRow(
                    key: ValueKey('role-candidate-${candidate.userId}'),
                    candidate: candidate,
                    sectionId: sectionId,
                    onTap: candidate.isActionable(sectionId)
                        ? () => onSelect(candidate)
                        : null,
                  ),
              ],
            ),
          ],
          if (state.isLoadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: SacLoadingSmall()),
            )
          else if (state.loadMoreFailed)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                children: [
                  Text(
                    'members.role_candidates.load_more_error'.tr(),
                    style: TextStyle(
                      fontSize: SacFontSize.bodySmall,
                      color: c.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SacButton(
                    text: 'common.retry'.tr(),
                    variant: SacButtonVariant.ghost,
                    size: SacButtonSize.small,
                    onPressed: onLoadMore,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
