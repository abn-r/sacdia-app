import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_grouped_section.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_annual_progress.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_annual_progress_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_messages.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_progress_parts.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_progress_sheet.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_scroll.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_segmented_control.dart';
import 'package:sacdia_app/providers/catalogs_provider.dart';

const String _kDivisionLevel = 'division';
const String _kUnionLevel = 'union';
const String _kLocalFieldLevel = 'local_field';

/// «Progreso anual» of the clubs of the territory.
///
/// The figures live per local field, so a Division first picks a union and a
/// Union a local field; each choice pushes this same screen one level down.
/// The server checks every id against the actor's territory.
class SupervisionAnnualProgressView extends ConsumerStatefulWidget {
  const SupervisionAnnualProgressView({
    super.key,
    this.unionId,
    this.localFieldId,
  });

  /// Union picked one level up (a Division drilling down).
  final int? unionId;

  /// Local field whose clubs are shown.
  final int? localFieldId;

  @override
  ConsumerState<SupervisionAnnualProgressView> createState() =>
      _SupervisionAnnualProgressViewState();
}

class _SupervisionAnnualProgressViewState
    extends ConsumerState<SupervisionAnnualProgressView> {
  /// Club type picked by hand; null follows the first of the catalog.
  int? _clubTypeId;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final territory = ref.watch(
      authNotifierProvider.select((v) => v.value?.authorization?.territory),
    );
    final level = territory?.level;
    final divisionId = level == _kDivisionLevel ? territory?.divisionId : null;
    final unionId =
        widget.unionId ?? (level == _kUnionLevel ? territory?.unionId : null);
    final localFieldId = widget.localFieldId ??
        (level == _kLocalFieldLevel ? territory?.localFieldId : null);

    final ownTitle = 'supervision.annual_progress.title'.tr();
    String title = ownTitle;
    String? subtitle;
    final Widget body;

    if (localFieldId != null) {
      // The name comes from the list one level up, still alive in the stack.
      final name = unionId == null
          ? null
          : _nameOf(
              ref.watch(supervisionLocalFieldsProvider(unionId)).value,
              localFieldId,
            );
      final yearName =
          ref.watch(supervisionProgressYearProvider).value?.name.trim() ?? '';
      // «Progreso anual · 2026»: the year is part of the subtitle.
      final yearLine = yearName.isEmpty ? ownTitle : '$ownTitle · $yearName';
      if (name != null) {
        title = name;
        subtitle = yearLine;
      } else if (yearName.isNotEmpty) {
        subtitle = yearLine;
      }
      body = _ClubsBody(
        localFieldId: localFieldId,
        clubTypeId: _clubTypeId,
        onClubType: (id) => setState(() => _clubTypeId = id),
      );
    } else if (unionId != null) {
      if (widget.unionId != null && divisionId != null) {
        final name = _nameOf(
          ref.watch(supervisionUnionsProvider(divisionId)).value,
          unionId,
        );
        if (name != null) {
          title = name;
          subtitle = ownTitle;
        }
      }
      body = _TerritoryList(
        provider: supervisionLocalFieldsProvider(unionId),
        labelKey: 'supervision.annual_progress.local_fields_title',
        hintKey: 'supervision.annual_progress.local_fields_hint',
        emptyKey: 'supervision.annual_progress.local_fields_empty',
        routeFor: (option) => RouteNames.supervisionAnnualProgressScope(
          unionId: unionId,
          localFieldId: option.id,
        ),
      );
    } else if (divisionId != null) {
      body = _TerritoryList(
        provider: supervisionUnionsProvider(divisionId),
        labelKey: 'supervision.annual_progress.unions_title',
        hintKey: 'supervision.annual_progress.unions_hint',
        emptyKey: 'supervision.annual_progress.unions_empty',
        routeFor: (option) =>
            RouteNames.supervisionAnnualProgressScope(unionId: option.id),
      );
    } else {
      // No union or division to start from.
      body = SupervisionScroll(
        onRefresh: () => ref
            .read(authNotifierProvider.notifier)
            .refreshAuthorization(minInterval: Duration.zero),
        fill: true,
        child: SacEmptyState(
          icon: HugeIcons.strokeRoundedAnalytics01,
          title: 'supervision.annual_progress.no_territory_title'.tr(),
          body: 'supervision.annual_progress.no_territory_body'.tr(),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(title: title, subtitle: subtitle, frosted: true),
      body: SacFrostedVeil(child: body),
    );
  }
}

String? _nameOf(List<SupervisionTerritoryOption>? options, int id) {
  if (options == null) return null;
  for (final option in options) {
    if (option.id == id) {
      final name = option.name.trim();
      return name.isEmpty ? null : name;
    }
  }
  return null;
}

Widget _skeleton() => const Padding(
      padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: SacSkeletonList(itemCount: 6, leading: false, scrollable: false),
    );

Widget _error(Object error, VoidCallback onRetry) => isForbiddenFailure(error)
    ? const ForbiddenView()
    : SacErrorState(
        title: 'supervision.annual_progress.error_title'.tr(),
        message: supervisionErrorMessage(null),
        onRetry: onRetry,
      );

// ── Picking where to look ───────────────────────────────────────────────────

class _TerritoryList extends ConsumerWidget {
  const _TerritoryList({
    required this.provider,
    required this.labelKey,
    required this.hintKey,
    required this.emptyKey,
    required this.routeFor,
  });

  final FutureProvider<List<SupervisionTerritoryOption>> provider;
  final String labelKey;
  final String hintKey;
  final String emptyKey;
  final String Function(SupervisionTerritoryOption option) routeFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final async = ref.watch(provider);
    final options = async.value;

    Future<void> refresh() async {
      ref.invalidate(provider);
      try {
        await ref.read(provider.future);
      } catch (_) {
        // The body renders the error.
      }
    }

    if (options == null && async.hasError) {
      return SupervisionScroll(
        onRefresh: refresh,
        fill: true,
        child: _error(async.error!, refresh),
      );
    }
    if (options == null) {
      return SupervisionScroll(onRefresh: refresh, child: _skeleton());
    }
    if (options.isEmpty) {
      return SupervisionScroll(
        onRefresh: refresh,
        fill: true,
        child: SacEmptyState(title: emptyKey.tr()),
      );
    }
    return SupervisionScroll(
      onRefresh: refresh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Text(
              hintKey.tr(),
              style: TextStyle(
                fontSize: SacFontSize.bodyMedium,
                height: 1.3,
                color: c.textSecondary,
              ),
            ),
          ),
          SacGroupedSection(
            label: labelKey.tr(),
            dividerIndent: 16,
            children: [
              for (final option in options)
                SupervisionTerritoryRow(
                  option: option,
                  onTap: () => context.push(routeFor(option)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── The clubs of one local field ────────────────────────────────────────────

class _ClubsBody extends ConsumerWidget {
  const _ClubsBody({
    required this.localFieldId,
    required this.clubTypeId,
    required this.onClubType,
  });

  final int localFieldId;
  final int? clubTypeId;
  final ValueChanged<int> onClubType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yearAsync = ref.watch(supervisionProgressYearProvider);
    final typesAsync = ref.watch(clubTypesProvider);
    final year = yearAsync.value;
    final types = typesAsync.value;

    Future<void> refreshCatalogs() async {
      ref.invalidate(supervisionProgressYearProvider);
      ref.invalidate(clubTypesProvider);
      try {
        await Future.wait([
          ref.read(supervisionProgressYearProvider.future),
          ref.read(clubTypesProvider.future),
        ]);
      } catch (_) {
        // The body renders the error.
      }
    }

    final catalogError = (types == null && typesAsync.hasError)
        ? typesAsync.error
        : (yearAsync.hasError && !yearAsync.hasValue ? yearAsync.error : null);
    if (catalogError != null) {
      return SupervisionScroll(
        onRefresh: refreshCatalogs,
        fill: true,
        child: _error(catalogError, refreshCatalogs),
      );
    }
    if (types == null || yearAsync.isLoading && year == null) {
      return SupervisionScroll(onRefresh: refreshCatalogs, child: _skeleton());
    }
    if (year == null || types.isEmpty) {
      return SupervisionScroll(
        onRefresh: refreshCatalogs,
        fill: true,
        child: SacEmptyState(
          icon: HugeIcons.strokeRoundedCalendar03,
          title: 'supervision.annual_progress.no_year_title'.tr(),
          body: 'supervision.annual_progress.no_year_body'.tr(),
        ),
      );
    }

    final type = types.firstWhere(
      (t) => t.clubTypeId == clubTypeId,
      orElse: () => types.first,
    );
    final SupervisionAnnualProgressQuery query = (
      localFieldId: localFieldId,
      clubTypeId: type.clubTypeId,
      yearId: year.ecclesiasticalYearId,
    );
    final provider = supervisionAnnualProgressProvider(query);
    final async = ref.watch(provider);
    final progress = async.value;

    Future<void> refresh() async {
      ref.invalidate(provider);
      try {
        await ref.read(provider.future);
      } catch (_) {
        // The body renders the error.
      }
    }

    final Widget list;
    if (progress == null && async.hasError) {
      list = Padding(
        padding: const EdgeInsets.only(top: 24),
        child: _error(async.error!, refresh),
      );
    } else if (progress == null) {
      list = _skeleton();
    } else if (!progress.configured) {
      list = Padding(
        padding: const EdgeInsets.only(top: 24),
        child: SacEmptyState(
          title: 'supervision.annual_progress.not_configured_title'.tr(),
          body: 'supervision.annual_progress.not_configured_body'
              .tr(args: [type.name]),
        ),
      );
    } else if (progress.clubs.isEmpty) {
      list = Padding(
        padding: const EdgeInsets.only(top: 24),
        child: SacEmptyState(
          title: 'supervision.annual_progress.empty_title'.tr(),
          body: 'supervision.annual_progress.empty_body'.tr(),
        ),
      );
    } else {
      list = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SupervisionTierBox(clubs: progress.clubs),
          SacGroupedSection(
            label: 'supervision.annual_progress.clubs_title'.tr(),
            dividerIndent: 64,
            children: [
              for (final club in progress.clubs)
                SupervisionClubProgressRow(
                  club: club,
                  onTap: () => showSupervisionClubProgressSheet(
                      context, club, type.name),
                ),
            ],
          ),
        ],
      );
    }

    return SupervisionScroll(
      onRefresh: refresh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (types.length > 1)
            SupervisionSegmentedControl<int>(
              selected: type.clubTypeId,
              onChanged: onClubType,
              segments: [
                for (final t in types)
                  SupervisionSegment(value: t.clubTypeId, label: t.name),
              ],
            ),
          list,
        ],
      ),
    );
  }
}
