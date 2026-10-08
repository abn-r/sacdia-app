import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_badge.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_dialog.dart';
import '../../../../core/widgets/sac_empty_state.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../../../core/widgets/sac_progress_bar.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../../providers/catalogs_provider.dart';
import '../../../../shared/models/catalogs/ecclesiastical_year_model.dart';
import '../../../members/presentation/providers/members_providers.dart';
import '../../data/investiture_request_error_keys.dart';
import '../../domain/entities/investiture_request.dart';
import '../../domain/entities/presentation_context.dart';
import '../providers/investiture_requests_providers.dart';
import '../utils/investiture_dates.dart';
import '../widgets/change_date_sheet.dart';
import '../widgets/investiture_banner.dart';
import '../widgets/investiture_person_row.dart';
import '../widgets/investiture_section_label.dart';
import '../widgets/present_sheet.dart';

const _i18n = 'investiture_requests.section';

/// Pantalla de la directiva de la sección: presentar, agregar, quitar y
/// cambiar la fecha de quienes cumplen los requisitos de su clase.
class SectionInvestitureView extends ConsumerWidget {
  const SectionInvestitureView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final clubAsync = ref.watch(clubContextProvider);
    final yearAsync = ref.watch(currentEcclesiasticalYearProvider);
    final club = clubAsync.valueOrNull;
    final isBoard = club?.isInvestitureBoard ?? false;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.canvas,
      appBar: SacTopBar(
        title: tr('$_i18n.title'),
        backgroundColor: c.canvas,
        frosted: true,
        actions: [
          if (isBoard)
            SacPressable(
              listenOnly: true,
              child: IconButton(
                enableFeedback: false,
                tooltip: tr('$_i18n.history_action'),
                onPressed: () =>
                    context.push(RouteNames.sectionInvestitureHistory),
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedTime04,
                  size: 22,
                  color: c.text,
                ),
              ),
            ),
        ],
      ),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) {
            if (club == null) {
              if (clubAsync.hasError) {
                return _MessageState(
                  title: tr('$_i18n.load_error_title'),
                  onRetry: () => ref.invalidate(clubContextProvider),
                );
              }
              return clubAsync.isLoading
                  ? const Center(child: SacLoading())
                  : _MessageState(
                      title: tr('$_i18n.restricted_title'),
                      body: tr('$_i18n.restricted_body'),
                      icon: HugeIcons.strokeRoundedLockKey,
                    );
            }
            if (!isBoard) {
              return _MessageState(
                title: tr('$_i18n.restricted_title'),
                body: tr('$_i18n.restricted_body'),
                icon: HugeIcons.strokeRoundedLockKey,
              );
            }
            final year = yearAsync.valueOrNull;
            if (year == null) {
              if (yearAsync.hasError) {
                return _MessageState(
                  title: tr('$_i18n.load_error_title'),
                  onRetry: () =>
                      ref.invalidate(currentEcclesiasticalYearProvider),
                );
              }
              return yearAsync.isLoading
                  ? const Center(child: SacLoading())
                  : _MessageState(
                      title: tr('$_i18n.no_year_title'),
                      body: tr('$_i18n.no_year_body'),
                      icon: HugeIcons.strokeRoundedCalendar03,
                    );
            }
            return _SectionBody(
              query: SectionYearQuery(
                sectionId: club.sectionId,
                yearId: year.ecclesiasticalYearId,
              ),
              year: year,
            );
          },
        ),
      ),
    );
  }
}

/// Estado a pantalla completa (acceso, sin datos, error) con reintento
/// opcional vía [onRetry].
class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.title,
    this.body,
    this.icon = HugeIcons.strokeRoundedAlert02,
    this.onRetry,
  });

  final String title;
  final String? body;
  final List<List<dynamic>> icon;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: SacTopBar.frostedInset(context)),
      child: SacEmptyState(
        title: title,
        body: body,
        icon: icon,
        actionLabel: onRetry == null ? null : tr('common.retry'),
        onAction: onRetry,
        actionIcon: HugeIcons.strokeRoundedRefresh,
        actionVariant: SacButtonVariant.outline,
      ),
    );
  }
}

class _SectionBody extends ConsumerStatefulWidget {
  const _SectionBody({required this.query, required this.year});

  final SectionYearQuery query;
  final EcclesiasticalYearModel year;

  @override
  ConsumerState<_SectionBody> createState() => _SectionBodyState();
}

class _SectionBodyState extends ConsumerState<_SectionBody> {
  final Set<int> _selectedEnrollments = {};
  final Set<String> _selectedPeople = {};

  SectionYearQuery get _query => widget.query;

  Future<void> _refresh() async {
    ref
      ..invalidate(presentationContextProvider(_query))
      ..invalidate(openRequestProvider(_query));
    try {
      await Future.wait([
        ref.read(presentationContextProvider(_query).future),
        ref.read(openRequestProvider(_query).future),
      ]);
    } catch (_) {
      // El error queda en el estado de los providers y se pinta abajo.
    }
  }

  /// Rango de fechas válido: ventana del Campo recortada al año eclesiástico.
  /// `null` si no se cruzan (nadie puede elegir una fecha).
  ({DateTime first, DateTime last})? _bounds(WindowState window) {
    final yearStart = civilDay(widget.year.startDate);
    final yearEnd = civilDay(widget.year.endDate);
    var first =
        window.startDate == null ? yearStart : civilDay(window.startDate!);
    var last = window.endDate == null ? yearEnd : civilDay(window.endDate!);
    if (first.isBefore(yearStart)) first = yearStart;
    if (last.isAfter(yearEnd)) last = yearEnd;
    if (first.isAfter(last)) return null;
    return (first: first, last: last);
  }

  void _toggleEnrollment(int id, bool selected) => setState(() {
        selected
            ? _selectedEnrollments.add(id)
            : _selectedEnrollments.remove(id);
      });

  void _togglePerson(String id, bool selected) => setState(() {
        selected ? _selectedPeople.add(id) : _selectedPeople.remove(id);
      });

  /// Cierra una acción: avisa el resultado; si falló, recarga para no operar
  /// sobre datos viejos (p. ej. `INVESTITURE_REQUEST_STALE`).
  void _finish(
    bool ok,
    String? errorMessage,
    String successKey, {
    Set<int>? clearEnrollments,
    Set<String>? clearPeople,
  }) {
    if (!mounted) return;
    if (ok) {
      setState(() {
        if (clearEnrollments != null) {
          _selectedEnrollments.removeAll(clearEnrollments);
        }
        if (clearPeople != null) _selectedPeople.removeAll(clearPeople);
      });
      SacSnackBar.show(context, tr(successKey));
      return;
    }
    SacSnackBar.show(
      context,
      errorMessage ?? tr('investiture_requests.errors.generic'),
      isError: true,
    );
    ref
      ..invalidate(presentationContextProvider(_query))
      ..invalidate(openRequestProvider(_query));
  }

  Future<void> _present({
    required PresentationContext ctx,
    required InvestitureRequest? request,
    required List<PresentationCandidate> selected,
  }) async {
    final bounds = _bounds(ctx.window);
    if (bounds == null || selected.isEmpty) return;
    final requestId = ctx.openRequestId ?? request?.requestId;
    final adding = requestId != null;
    final previous = adding ? _earliestPendingDate(request) : null;

    final date = await showPresentSheet(
      context,
      peopleCount: selected.length,
      firstDate: bounds.first,
      lastDate: bounds.last,
      adding: adding,
      previousDate: previous,
    );
    if (date == null || !mounted) return;

    final ids = selected.map((c) => c.enrollmentId).toList(growable: false);
    final bool ok;
    final String? error;
    if (requestId != null) {
      ok = await ref.read(addPeopleNotifierProvider(_query).notifier).submit(
            requestId: requestId,
            investitureDate: date,
            enrollmentIds: ids,
          );
      error = ref.read(addPeopleNotifierProvider(_query)).errorMessage;
    } else {
      ok = await ref
          .read(presentNotifierProvider(_query).notifier)
          .submit(investitureDate: date, enrollmentIds: ids);
      error = ref.read(presentNotifierProvider(_query)).errorMessage;
    }
    _finish(
      ok,
      error,
      adding ? '$_i18n.added' : '$_i18n.presented',
      clearEnrollments: ids.toSet(),
    );
  }

  Future<void> _changeDate({
    required PresentationContext ctx,
    required InvestitureRequest request,
    required List<RequestPerson> selected,
  }) async {
    final bounds = _bounds(ctx.window);
    if (bounds == null || selected.isEmpty) return;
    final current = selected
        .map((p) => civilDay(p.investitureDate))
        .reduce((a, b) => a.isBefore(b) ? a : b);

    final date = await showChangeDateSheet(
      context,
      peopleCount: selected.length,
      firstDate: bounds.first,
      lastDate: bounds.last,
      currentDate: current,
    );
    if (date == null || !mounted) return;

    final ids = selected.map((p) => p.personId).toList(growable: false);
    final ok =
        await ref.read(changeDatesNotifierProvider(_query).notifier).submit(
              requestId: request.requestId,
              investitureDate: date,
              personIds: ids,
            );
    _finish(
      ok,
      ref.read(changeDatesNotifierProvider(_query)).errorMessage,
      '$_i18n.date_changed',
      clearPeople: ids.toSet(),
    );
  }

  Future<void> _remove({
    required InvestitureRequest request,
    required RequestPerson person,
  }) async {
    final confirmed = await SacDialog.show(
      context,
      title: tr('$_i18n.remove_title'),
      content: tr(
        '$_i18n.remove_body',
        namedArgs: {'name': person.userName ?? tr('$_i18n.unnamed_person')},
      ),
      confirmLabel: tr('$_i18n.remove_action'),
      confirmIsDestructive: true,
    );
    if (confirmed != true || !mounted) return;

    final ok = await ref
        .read(removePersonNotifierProvider(_query).notifier)
        .submit(requestId: request.requestId, personId: person.personId);
    _finish(
      ok,
      ref.read(removePersonNotifierProvider(_query)).errorMessage,
      '$_i18n.removed',
      clearPeople: {person.personId},
    );
  }

  DateTime? _earliestPendingDate(InvestitureRequest? request) {
    final dates = request?.pendingPeople
        .map((p) => civilDay(p.investitureDate))
        .toList(growable: false);
    if (dates == null || dates.isEmpty) return null;
    return dates.reduce((a, b) => a.isBefore(b) ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    final contextAsync = ref.watch(presentationContextProvider(_query));
    final requestAsync = ref.watch(openRequestProvider(_query));
    // Mantiene vivos los notifiers de escritura mientras exista la pantalla.
    final busy = [
      ref.watch(presentNotifierProvider(_query)),
      ref.watch(addPeopleNotifierProvider(_query)),
      ref.watch(removePersonNotifierProvider(_query)),
      ref.watch(changeDatesNotifierProvider(_query)),
    ].any((state) => state.isLoading);

    final ctx = contextAsync.valueOrNull;
    final request = requestAsync.valueOrNull;
    if (ctx == null || (request == null && requestAsync.isLoading)) {
      if (contextAsync.hasError || requestAsync.hasError) {
        return _MessageState(
          title: tr('$_i18n.load_error_title'),
          body: (contextAsync.error ?? requestAsync.error)
              ?.toString()
              .replaceFirst('Exception: ', ''),
          onRetry: _refresh,
        );
      }
      return const Center(child: SacLoading());
    }

    final bounds = _bounds(ctx.window);
    final canPresent = ctx.yearOpen &&
        ctx.window.openToday &&
        !ctx.window.timeZoneInvalid &&
        bounds != null;
    final canManagePending = ctx.yearOpen && bounds != null;

    final pending = request?.pendingPeople ?? const <RequestPerson>[];
    final eligible = ctx.candidates
        .where((c) => c.eligible && c.pendingPersonId == null)
        .toList(growable: false);
    final blocked = ctx.candidates
        .where((c) => !c.eligible && c.pendingPersonId == null)
        .toList(growable: false);

    final selectedCandidates = eligible
        .where((c) => _selectedEnrollments.contains(c.enrollmentId))
        .toList(growable: false);
    final selectedPending = pending
        .where((p) => _selectedPeople.contains(p.personId))
        .toList(growable: false);
    final showPresentBar = canPresent && selectedCandidates.isNotEmpty;
    final showDateBar =
        canManagePending && selectedPending.isNotEmpty && request != null;
    final barButtons = (showPresentBar ? 1 : 0) + (showDateBar ? 1 : 0);
    final adding = (ctx.openRequestId ?? request?.requestId) != null;

    final isEmpty = eligible.isEmpty && blocked.isEmpty && pending.isEmpty;
    final c = context.sac;

    return Stack(
      children: [
        RefreshIndicator(
          color: SacAccent.of(context).color,
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: SacTopBar.paddingBelowBar(
              context,
              EdgeInsets.fromLTRB(16, 16, 16, 32 + barButtons * 64.0),
            ),
            children: [
              _WindowBanner(ctx: ctx),
              if (isEmpty) ...[
                const SizedBox(height: 48),
                SacEmptyState(
                  title: tr('$_i18n.empty_title'),
                  body: tr('$_i18n.empty_body'),
                  icon: HugeIcons.strokeRoundedUserGroup,
                ),
              ] else ...[
                if (pending.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  InvestitureSectionLabel(
                    title: tr('$_i18n.pending_title'),
                    count: pending.length,
                  ),
                  const SizedBox(height: 10),
                  for (final person in pending)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PendingRow(
                        person: person,
                        selectable: canManagePending,
                        selected: _selectedPeople.contains(person.personId),
                        busy: busy,
                        onSelected: (value) =>
                            _togglePerson(person.personId, value),
                        onRemove: request == null
                            ? null
                            : () => _remove(request: request, person: person),
                      ),
                    ),
                ],
                const SizedBox(height: 20),
                InvestitureSectionLabel(
                  title: tr('$_i18n.eligible_title'),
                  count: eligible.length,
                ),
                const SizedBox(height: 10),
                if (eligible.isEmpty)
                  Text(
                    tr('$_i18n.eligible_empty'),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: c.ink500),
                  )
                else
                  for (final candidate in eligible)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _CandidateRow(
                        candidate: candidate,
                        selectable: canPresent,
                        selected: _selectedEnrollments
                            .contains(candidate.enrollmentId),
                        onSelected: (value) =>
                            _toggleEnrollment(candidate.enrollmentId, value),
                      ),
                    ),
                if (blocked.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  InvestitureSectionLabel(
                    title: tr('$_i18n.blocked_title'),
                    count: blocked.length,
                  ),
                  const SizedBox(height: 10),
                  for (final candidate in blocked)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _BlockedRow(candidate: candidate),
                    ),
                ],
              ],
            ],
          ),
        ),
        if (barButtons > 0)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _ActionBar(
              children: [
                if (showPresentBar)
                  SacButton.primary(
                    text: tr(
                      adding ? '$_i18n.add_cta' : '$_i18n.present_cta',
                      namedArgs: {'count': '${selectedCandidates.length}'},
                    ),
                    icon: HugeIcons.strokeRoundedMedal01,
                    isEnabled: !busy,
                    isLoading: busy,
                    onPressed: () => _present(
                      ctx: ctx,
                      request: request,
                      selected: selectedCandidates,
                    ),
                  ),
                if (showDateBar)
                  SacButton.outline(
                    text: tr(
                      '$_i18n.change_date_cta',
                      namedArgs: {'count': '${selectedPending.length}'},
                    ),
                    icon: HugeIcons.strokeRoundedCalendar03,
                    isEnabled: !busy,
                    onPressed: () => _changeDate(
                      ctx: ctx,
                      request: request,
                      selected: selectedPending,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _WindowBanner extends StatelessWidget {
  const _WindowBanner({required this.ctx});

  final PresentationContext ctx;

  @override
  Widget build(BuildContext context) {
    final window = ctx.window;
    if (!ctx.yearOpen) {
      return InvestitureBanner(
        text: tr('$_i18n.year_closed'),
        icon: HugeIcons.strokeRoundedLockKey,
      );
    }
    if (window.timeZoneInvalid) {
      return InvestitureBanner(
        text: tr('$_i18n.window_time_zone_invalid'),
        tone: InvestitureBannerTone.caution,
      );
    }
    if (!window.openToday) {
      return InvestitureBanner(
        text: tr('$_i18n.window_closed'),
        tone: InvestitureBannerTone.caution,
        icon: HugeIcons.strokeRoundedCalendarLock01,
      );
    }
    final end = window.endDate;
    return InvestitureBanner(
      text: end == null
          ? tr('$_i18n.window_open_no_end')
          : tr(
              '$_i18n.window_open',
              namedArgs: {'date': formatInvestitureDate(context, end)},
            ),
      tone: InvestitureBannerTone.positive,
    );
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({
    required this.person,
    required this.selectable,
    required this.selected,
    required this.busy,
    required this.onSelected,
    required this.onRemove,
  });

  final RequestPerson person;
  final bool selectable;
  final bool selected;
  final bool busy;
  final ValueChanged<bool> onSelected;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final name = person.userName ?? tr('$_i18n.unnamed_person');
    final date = tr(
      '$_i18n.pending_date',
      namedArgs: {
        'date': formatInvestitureDate(context, person.investitureDate),
      },
    );
    return InvestiturePersonRow(
      name: name,
      className: person.className,
      detail:
          [if (person.className != null) person.className!, date].join(' · '),
      selected: selectable ? selected : null,
      onSelectedChanged: selectable ? onSelected : null,
      selectSemanticLabel:
          tr('$_i18n.select_person', namedArgs: {'name': name}),
      footer: Row(
        children: [
          SacBadge.warning(
            label: tr('$_i18n.pending_badge'),
            icon: HugeIcons.strokeRoundedClock01,
          ),
          const Spacer(),
          if (selectable && onRemove != null)
            SacButton(
              text: tr('$_i18n.remove_action'),
              variant: SacButtonVariant.outline,
              size: SacButtonSize.small,
              minHeight: 44,
              icon: HugeIcons.strokeRoundedDelete02,
              textColor: AppColors.error,
              borderColor: AppColors.error.withValues(alpha: 0.5),
              isEnabled: !busy,
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}

class _CandidateRow extends StatelessWidget {
  const _CandidateRow({
    required this.candidate,
    required this.selectable,
    required this.selected,
    required this.onSelected,
  });

  final PresentationCandidate candidate;
  final bool selectable;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final name = candidate.userName ?? tr('$_i18n.unnamed_person');
    final progress = candidate.overallProgress.clamp(0, 100).toDouble();
    return InvestiturePersonRow(
      name: name,
      className: candidate.className,
      detail: candidate.className,
      selected: selectable ? selected : null,
      onSelectedChanged: selectable ? onSelected : null,
      selectSemanticLabel:
          tr('$_i18n.select_person', namedArgs: {'name': name}),
      footer: SacProgressBar(
        progress: progress / 100,
        height: 8,
        color: AppColors.classColor(candidate.className ?? ''),
        label:
            tr('$_i18n.progress', namedArgs: {'value': '${progress.round()}'}),
      ),
    );
  }
}

class _BlockedRow extends StatelessWidget {
  const _BlockedRow({required this.candidate});

  final PresentationCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final reason = investitureRequestErrorMessage(candidate.blockedCode) ??
        tr('$_i18n.blocked_fallback');
    return InvestiturePersonRow(
      name: candidate.userName ?? tr('$_i18n.unnamed_person'),
      className: candidate.className,
      detail: candidate.className,
      footer: Text(
        reason,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.sac.ink600,
              height: 1.35,
            ),
      ),
    );
  }
}

/// Barra inferior con las acciones principales, a la altura del pulgar.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      decoration: BoxDecoration(
        color: c.canvas,
        border: Border(top: BorderSide(color: c.ink150)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
