import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/utils/back_or_home.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../core/widgets/sac_badge.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_dialog.dart';
import '../../../../core/widgets/sac_empty_state.dart';
import '../../../../core/widgets/sac_progress_bar.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../../../providers/catalogs_provider.dart';
import '../../../../shared/models/catalogs/ecclesiastical_year_model.dart';
import '../../../auth/domain/utils/authorization_utils.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../members/presentation/providers/members_providers.dart';
import '../../data/investiture_request_error_keys.dart';
import '../../domain/entities/investiture_request.dart';
import '../../domain/entities/presentation_context.dart';
import '../providers/investiture_requests_providers.dart';
import '../utils/investiture_dates.dart';
import '../utils/pastor_label.dart';
import '../utils/section_board.dart';
import '../widgets/change_date_sheet.dart';
import '../widgets/investiture_message_state.dart';
import '../widgets/investiture_rows.dart';
import '../widgets/investiture_skeleton.dart';
import '../widgets/present_sheet.dart';
import '../widgets/section_board_summary.dart';
import '../widgets/waiting_person_sheet.dart';

const _i18n = 'investiture_requests.section';

enum _MenuAction { history, yearbook, changeDate }

/// Tablero de la directiva de la sección: quién está listo para enviarse a
/// autorización, quién espera y quién aún no cumple. Los listos vienen
/// elegidos; un solo botón los envía.
class SectionInvestitureView extends ConsumerWidget {
  const SectionInvestitureView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubAsync = ref.watch(clubContextProvider);
    final yearAsync = ref.watch(currentEcclesiasticalYearProvider);
    final club = clubAsync.value;
    final user = ref.watch(authNotifierProvider.select((v) => v.value));
    // Directiva de la sección: `investiture.board` (calculada por el servidor
    // sobre la concesión activa) y un contexto de club resuelto.
    final isBoard = club != null && hasCapability(user, 'investiture.board');

    if (club == null && clubAsync.hasError) {
      return _shell(
        context,
        InvestitureMessageState.loadError(
          title: tr('$_i18n.load_error_title'),
          error: clubAsync.error,
          onRetry: () => ref.invalidate(clubContextProvider),
        ),
      );
    }
    if (club == null && clubAsync.isLoading) {
      return _shell(context, const InvestitureListSkeleton());
    }
    if (!isBoard) return _shell(context, _restricted(context));

    final year = yearAsync.value;
    if (year == null) {
      if (yearAsync.hasError) {
        return _shell(
          context,
          InvestitureMessageState.loadError(
            title: tr('$_i18n.load_error_title'),
            error: yearAsync.error,
            onRetry: () => ref.invalidate(currentEcclesiasticalYearProvider),
          ),
        );
      }
      return _shell(
        context,
        yearAsync.isLoading
            ? const InvestitureListSkeleton()
            : InvestitureMessageState(
                title: tr('$_i18n.no_year_title'),
                body: tr('$_i18n.no_year_body'),
                icon: HugeIcons.strokeRoundedCalendar03,
              ),
      );
    }
    return _BoardScaffold(
      query: SectionYearQuery(
        sectionId: club.sectionId,
        yearId: year.ecclesiasticalYearId,
      ),
      year: year,
      clubTypeName: club.clubTypeName,
    );
  }

  Widget _restricted(BuildContext context) => InvestitureMessageState(
        title: tr('$_i18n.restricted_title'),
        body: tr('$_i18n.restricted_body'),
        icon: HugeIcons.strokeRoundedLockKey,
        actionLabel: tr('$_i18n.see_mine'),
        onAction: () => context.push(RouteNames.ownInvestiture),
      );

  Widget _shell(BuildContext context, Widget body) {
    final c = context.sac;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.canvas,
      appBar: SacTopBar(
        title: '',
        backgroundColor: c.canvas,
        frosted: true,
        onBack: () => backOrHome(context),
      ),
      body: SacFrostedVeil(child: body),
    );
  }
}

class _BoardScaffold extends ConsumerStatefulWidget {
  const _BoardScaffold({
    required this.query,
    required this.year,
    required this.clubTypeName,
  });

  final SectionYearQuery query;
  final EcclesiasticalYearModel year;
  final String? clubTypeName;

  @override
  ConsumerState<_BoardScaffold> createState() => _BoardScaffoldState();
}

class _BoardScaffoldState extends ConsumerState<_BoardScaffold> {
  /// Los listos vienen elegidos: aquí se guardan quienes la directiva quitó.
  final Set<int> _deselected = {};

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
  /// `null` si el Campo no configuró la ventana o si no se cruzan.
  ({DateTime first, DateTime last})? _bounds(WindowState window) {
    final start = window.startDate;
    final end = window.endDate;
    if (start == null || end == null) return null;
    final yearStart = civilDay(widget.year.startDate);
    final yearEnd = civilDay(widget.year.endDate);
    var first = civilDay(start);
    var last = civilDay(end);
    if (first.isBefore(yearStart)) first = yearStart;
    if (last.isAfter(yearEnd)) last = yearEnd;
    if (first.isAfter(last)) return null;
    return (first: first, last: last);
  }

  /// Cierra una acción: avisa el resultado; si falló, recarga para no operar
  /// sobre datos viejos (p. ej. `INVESTITURE_REQUEST_STALE`).
  void _finish(bool ok, String? errorMessage, String successMessage) {
    if (!mounted) return;
    if (ok) {
      SacSnackBar.show(context, successMessage, isSuccess: true);
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

  DateTime? _earliestPending(Iterable<RequestPerson> people) {
    final dates = people.map((p) => civilDay(p.investitureDate)).toList();
    if (dates.isEmpty) return null;
    return dates.reduce((a, b) => a.isBefore(b) ? a : b);
  }

  Future<void> _present({
    required PresentationContext ctx,
    required SectionBoard board,
    required List<PresentationCandidate> selected,
  }) async {
    final bounds = _bounds(ctx.window);
    if (bounds == null || selected.isEmpty) return;
    final pastor = pastorLabel(ctx.authorizers);

    final date = await showPresentSheet(
      context,
      people: selected,
      firstDate: bounds.first,
      lastDate: bounds.last,
      pastor: pastor,
      currentDate: _earliestPending(board.waiting),
    );
    if (date == null || !mounted) return;

    final ok = await ref.read(presentNotifierProvider(_query).notifier).submit(
          investitureDate: date,
          enrollmentIds:
              selected.map((c) => c.enrollmentId).toList(growable: false),
        );
    _finish(
      ok,
      ref.read(presentNotifierProvider(_query)).errorMessage,
      pastor == null
          ? '$_i18n.presented_generic'.plural(selected.length)
          : '$_i18n.presented'
              .plural(selected.length, namedArgs: {'name': pastor}),
    );
  }

  Future<void> _changeDate({
    required PresentationContext ctx,
    required InvestitureRequest request,
    required List<RequestPerson> people,
  }) async {
    final bounds = _bounds(ctx.window);
    if (bounds == null || people.isEmpty) return;
    final date = await showChangeDateSheet(
      context,
      peopleCount: people.length,
      firstDate: bounds.first,
      lastDate: bounds.last,
      currentDate: _earliestPending(people)!,
    );
    if (date == null || !mounted) return;

    final ok =
        await ref.read(changeDatesNotifierProvider(_query).notifier).submit(
              requestId: request.requestId,
              investitureDate: date,
              personIds: people.map((p) => p.personId).toList(growable: false),
            );
    _finish(
      ok,
      ref.read(changeDatesNotifierProvider(_query)).errorMessage,
      tr('$_i18n.date_changed'),
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
      tr('$_i18n.removed'),
    );
  }

  Future<void> _openWaiting({
    required PresentationContext ctx,
    required InvestitureRequest? request,
    required RequestPerson person,
    required bool canManage,
  }) async {
    final action = await showWaitingPersonSheet(
      context,
      person: person,
      name: person.userName ?? tr('$_i18n.unnamed_person'),
      pastor: pastorLabel(ctx.authorizers),
      sentAt: request?.createdAt,
      canManage: canManage && request != null,
    );
    if (action == null || request == null || !mounted) return;
    switch (action) {
      case WaitingPersonAction.changeDate:
        await _changeDate(ctx: ctx, request: request, people: [person]);
      case WaitingPersonAction.remove:
        await _remove(request: request, person: person);
    }
  }

  void _onMenu(
    _MenuAction action,
    PresentationContext? ctx,
    InvestitureRequest? request,
  ) {
    switch (action) {
      case _MenuAction.history:
        context.push(RouteNames.sectionInvestitureHistory);
      case _MenuAction.yearbook:
        context.push('${RouteNames.sectionInvestitureHistory}?tab=yearbook');
      case _MenuAction.changeDate:
        if (ctx == null || request == null) return;
        _changeDate(ctx: ctx, request: request, people: request.pendingPeople);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final contextAsync = ref.watch(presentationContextProvider(_query));
    final requestAsync = ref.watch(openRequestProvider(_query));
    // Mantiene vivos los notifiers de escritura mientras exista la pantalla.
    final busy = [
      ref.watch(presentNotifierProvider(_query)),
      ref.watch(removePersonNotifierProvider(_query)),
      ref.watch(changeDatesNotifierProvider(_query)),
    ].any((state) => state.isLoading);

    final ctx = contextAsync.value;
    final request = requestAsync.value;
    final loaded = ctx != null && !(request == null && requestAsync.isLoading);

    Widget body;
    List<Widget> actions = const [];
    if (!loaded) {
      body = (contextAsync.hasError || requestAsync.hasError)
          ? InvestitureMessageState.loadError(
              title: tr('$_i18n.load_error_title'),
              error: contextAsync.error ?? requestAsync.error,
              onRetry: _refresh,
            )
          : const InvestitureListSkeleton();
    } else {
      final board = partitionSectionBoard(ctx, request);
      final closed = boardClosedReason(ctx);
      final canPresent = closed == null && _bounds(ctx.window) != null;
      final canManagePending = ctx.yearOpen && _bounds(ctx.window) != null;
      actions = [
        _BoardMenu(
          canChangeDate:
              canManagePending && request != null && board.waiting.isNotEmpty,
          onSelected: (a) => _onMenu(a, ctx, request),
        ),
      ];
      body = _body(
        context,
        ctx: ctx,
        request: request,
        board: board,
        closed: closed,
        canPresent: canPresent,
        canManagePending: canManagePending,
        busy: busy,
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.canvas,
      appBar: SacTopBar(
        title: '',
        backgroundColor: c.canvas,
        frosted: true,
        onBack: () => backOrHome(context),
        actions: actions,
      ),
      body: SacFrostedVeil(child: body),
    );
  }

  Widget _body(
    BuildContext context, {
    required PresentationContext ctx,
    required InvestitureRequest? request,
    required SectionBoard board,
    required BoardClosedReason? closed,
    required bool canPresent,
    required bool canManagePending,
    required bool busy,
  }) {
    final c = context.sac;
    final selected = board.ready
        .where((p) => !_deselected.contains(p.enrollmentId))
        .toList(growable: false);
    final showFooter = board.ready.isNotEmpty;
    final pastor = pastorLabel(ctx.authorizers);
    final subtitle = [
      if (widget.clubTypeName != null && widget.clubTypeName!.isNotEmpty)
        widget.clubTypeName!,
      if (widget.year.name.trim().isNotEmpty) widget.year.name.trim(),
    ].join(' · ');
    final nobodyReady = board.ready.isEmpty && board.waiting.isEmpty;

    return Stack(
      children: [
        RefreshIndicator(
          color: SacAccent.of(context).color,
          edgeOffset: SacTopBar.frostedInset(context),
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: SacTopBar.paddingBelowBar(
              context,
              EdgeInsets.only(
                top: 4,
                bottom: 32 + (showFooter ? InvestitureFooter.height : 0),
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Semantics(
                  header: true,
                  child: Text(
                    tr('$_i18n.title'),
                    style: TextStyle(
                      fontSize: SacFontSize.displayMedium,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: c.text,
                    ),
                  ),
                ),
              ),
              if (subtitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: SacFontSize.titleSmall,
                      color: c.textSecondary,
                    ),
                  ),
                ),
              if (board.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: SacEmptyState(
                    title: tr('$_i18n.empty_title'),
                    body: tr('$_i18n.empty_body'),
                    icon: HugeIcons.strokeRoundedUserGroup,
                  ),
                )
              else ...[
                SectionBoardSummary(
                    ctx: ctx, board: board, closedReason: closed),
                if (nobodyReady && board.notYet.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: SacEmptyState.inline(
                      title: tr('$_i18n.nobody_ready_title'),
                      body: tr('$_i18n.nobody_ready_body'),
                      icon: HugeIcons.strokeRoundedMedal01,
                    ),
                  ),
                if (board.ready.isNotEmpty)
                  _readyGroup(context, board, canPresent),
                if (board.waiting.isNotEmpty)
                  _waitingGroup(context, ctx, request, board, canManagePending),
                if (board.notYet.isNotEmpty)
                  _notYetGroup(context, board, nobodyReady),
              ],
            ],
          ),
        ),
        if (showFooter)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: InvestitureFooter(
              button: canPresent
                  ? SacButton.primary(
                      text: tr(
                        '$_i18n.send_cta',
                        namedArgs: {'count': '${selected.length}'},
                      ),
                      icon: HugeIcons.strokeRoundedSent,
                      isEnabled: selected.isNotEmpty && !busy,
                      isLoading: busy,
                      onPressed: () => _present(
                        ctx: ctx,
                        board: board,
                        selected: selected,
                      ),
                    )
                  : SacButton.primary(
                      text: tr('$_i18n.send_closed'),
                      icon: HugeIcons.strokeRoundedLockKey,
                      isEnabled: false,
                    ),
              note: canPresent
                  ? (pastor == null
                      ? tr('$_i18n.footer_pastor_generic')
                      : tr('$_i18n.footer_pastor', namedArgs: {'name': pastor}))
                  : null,
            ),
          ),
      ],
    );
  }

  Widget _readyGroup(
      BuildContext context, SectionBoard board, bool canPresent) {
    final allSelected = board.ready.every(
      (p) => !_deselected.contains(p.enrollmentId),
    );
    return SacGroupedSection(
      key: const ValueKey('board-group-ready'),
      label: tr('$_i18n.ready_title'),
      count: board.ready.length,
      action: canPresent
          ? InvestitureEyebrowAction(
              label:
                  tr(allSelected ? '$_i18n.select_none' : '$_i18n.select_all'),
              onTap: () => setState(() {
                if (allSelected) {
                  _deselected.addAll(board.ready.map((p) => p.enrollmentId));
                } else {
                  _deselected.clear();
                }
              }),
            )
          : null,
      children: [
        for (final candidate in board.ready)
          _ReadyRow(
            candidate: candidate,
            selectable: canPresent,
            selected: !_deselected.contains(candidate.enrollmentId),
            onToggle: () => setState(() {
              if (!_deselected.remove(candidate.enrollmentId)) {
                _deselected.add(candidate.enrollmentId);
              }
            }),
          ),
      ],
    );
  }

  Widget _waitingGroup(
    BuildContext context,
    PresentationContext ctx,
    InvestitureRequest? request,
    SectionBoard board,
    bool canManage,
  ) {
    return SacGroupedSection(
      key: const ValueKey('board-group-waiting'),
      label: tr('$_i18n.pending_title'),
      children: [
        for (final person in board.waiting)
          _WaitingRow(
            person: person,
            onTap: () => _openWaiting(
              ctx: ctx,
              request: request,
              person: person,
              canManage: canManage,
            ),
          ),
      ],
    );
  }

  /// Opens the member's progress in the redesigned grouped-class flow (named,
  /// requirements grouped by status). Falls back to the plain class detail
  /// only when the club context is not resolved.
  void _openCandidateProgress(
    BuildContext context,
    PresentationCandidate candidate,
  ) {
    final clubId = ref.read(clubContextProvider).value?.clubId;
    if (clubId == null) {
      context.push(
        RouteNames.classDetailPath(
          '${candidate.classId}',
          enrollmentId: candidate.enrollmentId,
          targetUserId: candidate.userId,
        ),
      );
      return;
    }
    context.push(
      RouteNames.groupedClassMemberPath(
        candidate.classId,
        candidate.userId,
        clubId: clubId,
        sectionId: widget.query.sectionId,
        enrollmentId: candidate.enrollmentId,
        yearId: widget.query.yearId,
        className: candidate.className,
        memberName: candidate.userName,
      ),
    );
  }

  Widget _notYetGroup(BuildContext context, SectionBoard board, bool closest) {
    return SacGroupedSection(
      key: const ValueKey('board-group-not-yet'),
      label: tr(closest ? '$_i18n.closest_title' : '$_i18n.blocked_title'),
      children: [
        for (final candidate in board.notYet)
          _NotYetRow(
            candidate: candidate,
            onTap: () => _openCandidateProgress(context, candidate),
          ),
      ],
    );
  }
}

class _BoardMenu extends StatelessWidget {
  const _BoardMenu({required this.canChangeDate, required this.onSelected});

  final bool canChangeDate;
  final ValueChanged<_MenuAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    PopupMenuItem<_MenuAction> item(
      _MenuAction value,
      HugeIconData icon,
      String label,
    ) =>
        PopupMenuItem<_MenuAction>(
          value: value,
          height: 48,
          child: Row(
            children: [
              buildIcon(icon, size: 18, color: c.text),
              const SizedBox(width: 10),
              Text(label),
            ],
          ),
        );

    return PopupMenuButton<_MenuAction>(
      tooltip: tr('$_i18n.more_options'),
      icon: HugeIcon(
        icon: HugeIcons.strokeRoundedMoreHorizontal,
        size: 22,
        color: c.text,
      ),
      onSelected: onSelected,
      itemBuilder: (_) => [
        item(
          _MenuAction.history,
          HugeIcons.strokeRoundedTime04,
          tr('$_i18n.menu_history'),
        ),
        item(
          _MenuAction.yearbook,
          HugeIcons.strokeRoundedBookOpen01,
          tr('$_i18n.menu_yearbook'),
        ),
        if (canChangeDate)
          item(
            _MenuAction.changeDate,
            HugeIcons.strokeRoundedCalendar03,
            tr('$_i18n.menu_change_date'),
          ),
      ],
    );
  }
}

String _nameOf(String? name) => name?.trim().isNotEmpty ?? false
    ? name!.trim()
    : tr('$_i18n.unnamed_person');

class _ReadyRow extends StatelessWidget {
  const _ReadyRow({
    required this.candidate,
    required this.selectable,
    required this.selected,
    required this.onToggle,
  });

  final PresentationCandidate candidate;
  final bool selectable;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final name = _nameOf(candidate.userName);
    final progress = candidate.overallProgress.clamp(0, 100).round();
    return InvestitureRow(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selectable) ...[
            InvestitureSelectBox(selected: selected),
            const SizedBox(width: 12),
          ],
          InvestitureAvatar(name: name),
        ],
      ),
      title: name,
      detail: candidate.className,
      trailing: SacBadge.success(
        label: tr('$_i18n.progress_pct', namedArgs: {'value': '$progress'}),
      ),
      selected: selectable ? selected : null,
      semanticLabel: selectable
          ? tr('$_i18n.select_person', namedArgs: {'name': name})
          : null,
      onTap: selectable ? onToggle : null,
    );
  }
}

class _WaitingRow extends StatelessWidget {
  const _WaitingRow({required this.person, required this.onTap});

  final RequestPerson person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = _nameOf(person.userName);
    final date = tr(
      '$_i18n.waiting_date',
      namedArgs: {
        'date': formatInvestitureDate(context, person.investitureDate),
      },
    );
    return InvestitureRow(
      leading: InvestitureAvatar(name: name),
      title: name,
      detail: [
        if (person.className != null && person.className!.isNotEmpty)
          person.className!,
        date,
      ].join(' · '),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SacBadge.info(
              label: tr('$_i18n.pending_badge'),
              icon: HugeIcons.strokeRoundedClock01,
            ),
          ),
          const SizedBox(width: 4),
          const InvestitureChevron(),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _NotYetRow extends StatelessWidget {
  const _NotYetRow({required this.candidate, required this.onTap});

  final PresentationCandidate candidate;
  final VoidCallback onTap;

  String _reason() {
    final missing = candidate.missingRequirementsCount;
    if (missing != null && missing > 0) {
      return '$_i18n.missing_requirements'.plural(missing);
    }
    return investitureRequestErrorMessage(candidate.blockedCode) ??
        tr('$_i18n.blocked_fallback');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final name = _nameOf(candidate.userName);
    final progress = candidate.overallProgress.clamp(0, 100).toDouble();
    return InvestitureRow(
      leading: InvestitureAvatar(name: name, muted: true),
      title: name,
      detail: [
        if (candidate.className != null && candidate.className!.isNotEmpty)
          candidate.className!,
        _reason(),
      ].join(' · '),
      detailMaxLines: 2,
      extra: SizedBox(
        width: 120,
        child: SacProgressBar(
          progress: progress / 100,
          height: 4,
          color: c.textTertiary,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tr('$_i18n.progress_pct',
                namedArgs: {'value': '${progress.round()}'}),
            style: TextStyle(
              fontSize: SacFontSize.titleMedium,
              fontWeight: FontWeight.w700,
              color: c.textTertiary,
            ),
          ),
          const SizedBox(width: 4),
          const InvestitureChevron(),
        ],
      ),
      onTap: onTap,
    );
  }
}
