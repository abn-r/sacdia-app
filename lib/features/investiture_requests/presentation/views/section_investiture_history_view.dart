import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_badge.dart';
import '../../../../core/widgets/sac_empty_state.dart';
import '../../../../core/widgets/sac_filter_chip.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../../providers/catalogs_provider.dart';
import '../../../members/presentation/providers/members_providers.dart';
import '../../domain/entities/own_investiture_entry.dart';
import '../../domain/entities/person_status.dart';
import '../../domain/entities/yearbook_entry.dart';
import '../providers/investiture_requests_providers.dart';
import '../utils/investiture_dates.dart';
import '../utils/investiture_history_grouping.dart';
import '../widgets/investiture_message_state.dart';
import '../widgets/investiture_person_row.dart';
import '../widgets/investiture_section_label.dart';

const _i18n = 'investiture_requests.history';
const _sectionI18n = 'investiture_requests.section';

enum _HistoryTab { history, yearbook }

/// Historial de investiduras y anuario de inscripciones de la sección, para la
/// directiva. Se entra desde la pantalla de la directiva.
class SectionInvestitureHistoryView extends ConsumerStatefulWidget {
  const SectionInvestitureHistoryView({super.key});

  @override
  ConsumerState<SectionInvestitureHistoryView> createState() =>
      _SectionInvestitureHistoryViewState();
}

class _SectionInvestitureHistoryViewState
    extends ConsumerState<SectionInvestitureHistoryView> {
  _HistoryTab _tab = _HistoryTab.history;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final clubAsync = ref.watch(clubContextProvider);
    final club = clubAsync.valueOrNull;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.canvas,
      appBar: SacTopBar(
        title: tr('$_i18n.title'),
        backgroundColor: c.canvas,
        frosted: true,
      ),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) {
            if (club == null) {
              if (clubAsync.hasError) {
                return InvestitureMessageState(
                  title: tr('$_i18n.load_error_title'),
                  onRetry: () => ref.invalidate(clubContextProvider),
                );
              }
              return clubAsync.isLoading
                  ? const Center(child: SacLoading())
                  : _restricted();
            }
            if (!club.isInvestitureBoard) return _restricted();
            return _Body(
              sectionId: club.sectionId,
              tab: _tab,
              onTabChanged: (tab) => setState(() => _tab = tab),
            );
          },
        ),
      ),
    );
  }

  Widget _restricted() => InvestitureMessageState(
        title: tr('$_sectionI18n.restricted_title'),
        body: tr('$_sectionI18n.restricted_body'),
        icon: HugeIcons.strokeRoundedLockKey,
      );
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.sectionId,
    required this.tab,
    required this.onTabChanged,
  });

  final int sectionId;
  final _HistoryTab tab;
  final ValueChanged<_HistoryTab> onTabChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync =
        ref.watch(sectionInvestitureHistoryProvider(sectionId));
    final yearbookAsync = ref.watch(sectionYearbookProvider(sectionId));
    final isHistory = tab == _HistoryTab.history;

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

    final tabs = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SacFilterChip(
            label: tr('$_i18n.tab_history'),
            selected: isHistory,
            onTap: () => onTabChanged(_HistoryTab.history),
          ),
          const SizedBox(width: 8),
          SacFilterChip(
            label: tr('$_i18n.tab_yearbook'),
            selected: !isHistory,
            onTap: () => onTabChanged(_HistoryTab.yearbook),
          ),
        ],
      ),
    );

    Widget content;
    if (loading.valueOrNull == null) {
      if (loading.hasError) {
        content = SizedBox(
          height: 360,
          child: SacEmptyState(
            title: tr(
              isHistory
                  ? '$_i18n.load_error_title'
                  : '$_i18n.yearbook_load_error_title',
            ),
            icon: HugeIcons.strokeRoundedAlert02,
            actionLabel: tr('common.retry'),
            actionIcon: HugeIcons.strokeRoundedRefresh,
            onAction: refresh,
          ),
        );
      } else {
        content =
            const SizedBox(height: 280, child: Center(child: SacLoading()));
      }
    } else if (isHistory) {
      content = _HistoryList(entries: historyAsync.value!);
    } else {
      content = _YearbookList(entries: yearbookAsync.value!);
    }

    return RefreshIndicator(
      color: SacAccent.of(context).color,
      onRefresh: refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: SacTopBar.paddingBelowBar(
          context,
          const EdgeInsets.fromLTRB(16, 16, 16, 32),
        ),
        children: [tabs, content],
      ),
    );
  }
}

/// Nombre del año eclesiástico del catálogo; respaldo neutro si no está.
String _yearLabel(WidgetRef ref, int yearId) {
  final years = ref.watch(ecclesiasticalYearsProvider(null)).valueOrNull;
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

/// Encabezado de un año, con el total de personas.
class _YearHeader extends ConsumerWidget {
  const _YearHeader({required this.yearId, required this.count});

  final int yearId;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: InvestitureSectionLabel(
        title: _yearLabel(ref, yearId),
        count: count,
      ),
    );
  }
}

/// Encabezado de una clase dentro de un año.
class _ClassHeader extends StatelessWidget {
  const _ClassHeader({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Text(
        name ?? tr('$_i18n.class_fallback'),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.sac.ink600,
            ),
      ),
    );
  }
}

class _HistoryList extends ConsumerWidget {
  const _HistoryList({required this.entries});

  final List<OwnInvestitureEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = entries.where(_isHistoryStatus).toList(growable: false);
    if (visible.isEmpty) {
      return SizedBox(
        height: 360,
        child: SacEmptyState(
          title: tr('$_i18n.empty_title'),
          body: tr('$_i18n.empty_body'),
          icon: HugeIcons.strokeRoundedTime04,
        ),
      );
    }
    final names = ref.watch(sectionPeopleNamesProvider);
    final groups = groupByYearAndClass<OwnInvestitureEntry>(
      visible,
      yearOf: (e) => e.ecclesiasticalYearId,
      classIdOf: (e) => e.classId,
      classNameOf: (e) => e.className,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final year in groups) ...[
          _YearHeader(yearId: year.yearId, count: year.count),
          for (final group in year.classes) ...[
            _ClassHeader(name: group.className),
            for (final entry in _newestFirst(group.items))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _HistoryRow(
                  entry: entry,
                  name: _personName(names, entry.userId),
                ),
              ),
          ],
        ],
      ],
    );
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

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry, required this.name});

  final OwnInvestitureEntry entry;
  final String name;

  @override
  Widget build(BuildContext context) {
    final reason = _reason();
    final badge = switch (entry.status) {
      PersonStatus.invested => SacBadge.success(
          label: tr('$_i18n.status_invested'),
          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
        ),
      PersonStatus.closedYear => SacBadge.warning(
          label: tr('$_i18n.status_closed_year'),
          icon: HugeIcons.strokeRoundedCalendar03,
        ),
      _ => SacBadge.error(
          label: tr('$_i18n.status_not_invested'),
          icon: HugeIcons.strokeRoundedAlert02,
        ),
    };

    return InvestiturePersonRow(
      name: name,
      className: entry.className,
      detail: formatInvestitureDate(context, entry.investitureDate),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(alignment: Alignment.centerLeft, child: badge),
          if (reason != null) ...[
            const SizedBox(height: 8),
            Text(
              tr('$_i18n.reason', namedArgs: {'reason': reason}),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.sac.ink600,
                    height: 1.35,
                  ),
            ),
          ],
        ],
      ),
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

class _YearbookList extends ConsumerWidget {
  const _YearbookList({required this.entries});

  final List<YearbookEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (entries.isEmpty) {
      return SizedBox(
        height: 360,
        child: SacEmptyState(
          title: tr('$_i18n.yearbook_empty_title'),
          body: tr('$_i18n.yearbook_empty_body'),
          icon: HugeIcons.strokeRoundedBookOpen01,
        ),
      );
    }
    final names = ref.watch(sectionPeopleNamesProvider);
    final groups = groupByYearAndClass<YearbookEntry>(
      entries,
      yearOf: (e) => e.ecclesiasticalYearId,
      classIdOf: (e) => e.classId,
      classNameOf: (e) => e.className,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final year in groups) ...[
          _YearHeader(yearId: year.yearId, count: year.count),
          for (final group in year.classes) ...[
            _ClassHeader(name: group.className),
            for (final entry in group.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InvestiturePersonRow(
                  name: _personName(names, entry.userId),
                  className: entry.className,
                ),
              ),
          ],
        ],
      ],
    );
  }
}
