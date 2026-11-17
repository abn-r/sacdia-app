import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_badge.dart';
import '../../../../core/widgets/sac_empty_state.dart';
import '../../../../core/widgets/sac_filter_chip.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../../../providers/catalogs_provider.dart';
import '../../../auth/domain/utils/authorization_utils.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../members/presentation/providers/members_providers.dart';
import '../../domain/entities/own_investiture_entry.dart';
import '../../domain/entities/person_status.dart';
import '../../domain/entities/yearbook_entry.dart';
import '../providers/investiture_requests_providers.dart';
import '../utils/investiture_dates.dart';
import '../utils/investiture_history_grouping.dart';
import '../widgets/investiture_message_state.dart';
import '../widgets/investiture_rows.dart';
import '../widgets/investiture_skeleton.dart';

const _i18n = 'investiture_requests.history';
const _sectionI18n = 'investiture_requests.section';

enum HistoryTab { history, yearbook }

/// Historial de investiduras y anuario de inscripciones de la sección, para la
/// directiva. Se entra desde el menú del tablero.
class SectionInvestitureHistoryView extends ConsumerStatefulWidget {
  const SectionInvestitureHistoryView({
    super.key,
    this.initialTab = HistoryTab.history,
  });

  final HistoryTab initialTab;

  @override
  ConsumerState<SectionInvestitureHistoryView> createState() =>
      _SectionInvestitureHistoryViewState();
}

class _SectionInvestitureHistoryViewState
    extends ConsumerState<SectionInvestitureHistoryView> {
  late HistoryTab _tab = widget.initialTab;
  int? _yearId;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final clubAsync = ref.watch(clubContextProvider);
    final club = clubAsync.value;
    final isBoard = hasCapability(
      ref.watch(authNotifierProvider.select((v) => v.value)),
      'investiture.board',
    );

    Widget body;
    if (club == null) {
      if (clubAsync.hasError) {
        body = InvestitureMessageState.loadError(
          title: tr('$_i18n.load_error_title'),
          error: clubAsync.error,
          onRetry: () => ref.invalidate(clubContextProvider),
        );
      } else {
        body = clubAsync.isLoading
            ? const InvestitureListSkeleton()
            : _restricted(context);
      }
    } else if (!isBoard) {
      body = _restricted(context);
    } else {
      body = _Body(
        sectionId: club.sectionId,
        tab: _tab,
        yearId: _yearId,
        onTabChanged: (tab) => setState(() => _tab = tab),
        onYearChanged: (year) => setState(() => _yearId = year),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.canvas,
      appBar: SacTopBar(
        title: tr('$_i18n.title'),
        backgroundColor: c.canvas,
        frosted: true,
      ),
      body: SacFrostedVeil(child: body),
    );
  }

  Widget _restricted(BuildContext context) => InvestitureMessageState(
        title: tr('$_sectionI18n.restricted_title'),
        body: tr('$_sectionI18n.restricted_body'),
        icon: HugeIcons.strokeRoundedLockKey,
        actionLabel: tr('$_sectionI18n.see_mine'),
        onAction: () => context.push(RouteNames.ownInvestiture),
      );
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.sectionId,
    required this.tab,
    required this.yearId,
    required this.onTabChanged,
    required this.onYearChanged,
  });

  final int sectionId;
  final HistoryTab tab;
  final int? yearId;
  final ValueChanged<HistoryTab> onTabChanged;
  final ValueChanged<int> onYearChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync =
        ref.watch(sectionInvestitureHistoryProvider(sectionId));
    final yearbookAsync = ref.watch(sectionYearbookProvider(sectionId));
    final isHistory = tab == HistoryTab.history;
    final loading = isHistory ? historyAsync : yearbookAsync;

    Future<void> refresh() async {
      if (isHistory) {
        ref.invalidate(sectionInvestitureHistoryProvider(sectionId));
        try {
          await ref.read(sectionInvestitureHistoryProvider(sectionId).future);
        } catch (_) {
          // El error se pinta desde el estado del provider.
        }
      } else {
        ref.invalidate(sectionYearbookProvider(sectionId));
        try {
          await ref.read(sectionYearbookProvider(sectionId).future);
        } catch (_) {
          // El error se pinta desde el estado del provider.
        }
      }
    }

    if (loading.value == null) {
      if (loading.hasError) {
        return InvestitureMessageState.loadError(
          title: tr(
            isHistory
                ? '$_i18n.load_error_title'
                : '$_i18n.yearbook_load_error_title',
          ),
          error: loading.error,
          onRetry: refresh,
        );
      }
      return const InvestitureListSkeleton();
    }

    final List<OwnInvestitureEntry> historyEntries = isHistory
        ? historyAsync.requireValue.where(_isHistoryStatus).toList()
        : const [];
    final yearbookEntries =
        isHistory ? const <YearbookEntry>[] : yearbookAsync.requireValue;

    final years = <int>{
      for (final e in historyEntries) e.ecclesiasticalYearId,
      for (final e in yearbookEntries) e.ecclesiasticalYearId,
    }.toList()
      ..sort((a, b) => b.compareTo(a));
    final selectedYear =
        years.contains(yearId) ? yearId! : (years.isEmpty ? null : years.first);

    final names = ref.watch(sectionPeopleNamesProvider);

    return RefreshIndicator(
      color: SacAccent.of(context).color,
      edgeOffset: SacTopBar.frostedInset(context),
      onRefresh: refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: SacTopBar.paddingBelowBar(
          context,
          const EdgeInsets.only(top: 4, bottom: 32),
        ),
        children: [
          _Segmented(tab: tab, onChanged: onTabChanged),
          if (years.length > 1)
            _YearChips(
              years: years,
              selected: selectedYear,
              onChanged: onYearChanged,
            ),
          if (selectedYear == null)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: SacEmptyState(
                title: tr(
                  isHistory
                      ? '$_i18n.empty_title'
                      : '$_i18n.yearbook_empty_title',
                ),
                body: tr(
                  isHistory
                      ? '$_i18n.empty_body'
                      : '$_i18n.yearbook_empty_body',
                ),
                icon: isHistory
                    ? HugeIcons.strokeRoundedTime04
                    : HugeIcons.strokeRoundedBookOpen01,
              ),
            )
          else if (isHistory)
            ..._historyContent(
              context,
              ref,
              historyEntries
                  .where((e) => e.ecclesiasticalYearId == selectedYear)
                  .toList(),
              selectedYear,
              names,
            )
          else
            ..._yearbookContent(
              context,
              ref,
              yearbookEntries
                  .where((e) => e.ecclesiasticalYearId == selectedYear)
                  .toList(),
              selectedYear,
              names,
            ),
        ],
      ),
    );
  }

  List<Widget> _historyContent(
    BuildContext context,
    WidgetRef ref,
    List<OwnInvestitureEntry> entries,
    int year,
    Map<String, String> names,
  ) {
    final c = context.sac;
    final invested =
        entries.where((e) => e.status == PersonStatus.invested).length;
    final notInvested = entries.length - invested;
    final groups = groupByYearAndClass<OwnInvestitureEntry>(
      entries,
      yearOf: (e) => e.ecclesiasticalYearId,
      classIdOf: (e) => e.classId,
      classNameOf: (e) => e.className,
    );
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: SacSummaryBox(
          color: c.surfaceVariant,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _yearLabel(ref, year),
                style: TextStyle(
                  fontSize: SacFontSize.bodySmall,
                  fontWeight: FontWeight.w600,
                  color: c.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text.rich(
                key: const ValueKey('history-year-summary'),
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$invested',
                      style: TextStyle(
                        fontSize: SacFontSize.displayMedium,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                        color: c.text,
                      ),
                    ),
                    TextSpan(
                      text: ' ${'$_i18n.summary_invested'.plural(invested)}'
                          '${notInvested > 0 ? ' · ${'$_i18n.summary_not_invested'.plural(notInvested)}' : ''}',
                      style: TextStyle(
                        fontSize: SacFontSize.bodyMedium,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      for (final year in groups)
        for (final group in year.classes)
          SacGroupedSection(
            key: ValueKey('history-class-${group.classId}'),
            label: group.className ?? tr('$_i18n.class_fallback'),
            children: [
              for (final entry in _newestFirst(group.items))
                _HistoryRow(
                  entry: entry,
                  name: _personName(names, entry.userId),
                ),
            ],
          ),
    ];
  }

  List<Widget> _yearbookContent(
    BuildContext context,
    WidgetRef ref,
    List<YearbookEntry> entries,
    int year,
    Map<String, String> names,
  ) {
    final groups = groupByYearAndClass<YearbookEntry>(
      entries,
      yearOf: (e) => e.ecclesiasticalYearId,
      classIdOf: (e) => e.classId,
      classNameOf: (e) => e.className,
    );
    return [
      for (final yearGroup in groups)
        for (final group in yearGroup.classes)
          SacGroupedSection(
            key: ValueKey('yearbook-class-${group.classId}'),
            label:
                '${group.className ?? tr('$_i18n.class_fallback')} · ${_yearLabel(ref, year)}',
            children: [
              for (final entry in group.items)
                InvestitureRow(
                  leading: InvestitureAvatar(
                    name: _personName(names, entry.userId),
                  ),
                  title: _personName(names, entry.userId),
                ),
            ],
          ),
    ];
  }

  static bool _isHistoryStatus(OwnInvestitureEntry entry) {
    switch (entry.status) {
      case PersonStatus.invested:
      case PersonStatus.rejected:
      case PersonStatus.rejectedByPerson:
      case PersonStatus.rejectedBySystem:
      case PersonStatus.closedYear:
        return true;
      default:
        return false;
    }
  }

  static List<OwnInvestitureEntry> _newestFirst(
    List<OwnInvestitureEntry> items,
  ) =>
      [...items]
        ..sort((a, b) => b.investitureDate.compareTo(a.investitureDate));
}

/// Nombre del año eclesiástico del catálogo; respaldo neutro si no está.
String _yearLabel(WidgetRef ref, int yearId) {
  final years = ref.watch(ecclesiasticalYearsProvider(null)).value;
  if (years != null) {
    for (final year in years) {
      if (year.ecclesiasticalYearId == yearId && year.name.trim().isNotEmpty) {
        return year.name.trim();
      }
    }
  }
  return tr('$_i18n.year_fallback');
}

String _personName(Map<String, String> names, String userId) =>
    names[userId] ?? tr('$_sectionI18n.unnamed_person');

/// Control segmentado Historial / Anuario.
class _Segmented extends StatelessWidget {
  const _Segmented({required this.tab, required this.onChanged});

  final HistoryTab tab;
  final ValueChanged<HistoryTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    Widget segment(HistoryTab value, String label) {
      final selected = tab == value;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          child: SacInkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusSM - 2),
            onTap: () => onChanged(value),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? c.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(AppTheme.radiusSM - 2),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: SacFontSize.bodyMedium,
                  fontWeight: FontWeight.w600,
                  color: selected ? c.text : c.textSecondary,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: c.surfaceVariant,
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        ),
        child: Row(
          children: [
            segment(HistoryTab.history, tr('$_i18n.tab_history')),
            segment(HistoryTab.yearbook, tr('$_i18n.tab_yearbook')),
          ],
        ),
      ),
    );
  }
}

class _YearChips extends ConsumerWidget {
  const _YearChips({
    required this.years,
    required this.selected,
    required this.onChanged,
  });

  final List<int> years;
  final int? selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: SacFilterChip.barHeight + 8,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        itemCount: years.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => SacFilterChip(
          label: _yearLabel(ref, years[i]),
          selected: years[i] == selected,
          onTap: () => onChanged(years[i]),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry, required this.name});

  final OwnInvestitureEntry entry;
  final String name;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final reason = _reason();
    final date = formatInvestitureDate(
      context,
      entry.resolvedAt?.toLocal() ?? entry.investitureDate,
    );
    final by = entry.resolvedByName?.trim();
    final dateLine = [date, if (by != null && by.isNotEmpty) by].join(' · ');

    final badge = switch (entry.status) {
      PersonStatus.invested => SacBadge.success(
          label: tr('$_i18n.status_invested'),
        ),
      PersonStatus.closedYear => SacBadge.warning(
          label: tr('$_i18n.status_closed_year'),
        ),
      _ => SacBadge.error(label: tr('$_i18n.status_not_invested')),
    };

    return InvestitureRow(
      leading: InvestitureAvatar(name: name),
      title: name,
      detail: reason == null
          ? dateLine
          : tr('$_i18n.reason', namedArgs: {'reason': reason}),
      detailColor: reason == null ? null : c.onErrorContainer,
      detailMaxLines: 2,
      trailing: badge,
    );
  }

  /// Motivo humano, solo si el backend lo manda para la directiva.
  String? _reason() {
    if (entry.status == PersonStatus.invested ||
        entry.status == PersonStatus.closedYear) {
      return null;
    }
    for (final candidate in [entry.rejectionReason, entry.systemReason]) {
      final text = candidate?.trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }
}
