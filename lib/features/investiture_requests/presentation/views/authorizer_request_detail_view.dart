import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../core/widgets/sac_badge.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_dialog.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../data/investiture_request_error_keys.dart';
import '../../domain/entities/investiture_request.dart';
import '../../domain/entities/investiture_resolution.dart';
import '../../domain/entities/person_status.dart';
import '../providers/investiture_requests_providers.dart';
import '../utils/authorizer_decisions.dart';
import '../utils/investiture_dates.dart';
import '../widgets/authorizer_result.dart';
import '../widgets/investiture_message_state.dart';
import '../widgets/investiture_rows.dart';
import '../widgets/investiture_skeleton.dart';
import '../widgets/reject_reason_sheet.dart';

const _i18n = 'investiture_requests.authorizer';

/// Por qué el backend dejó de aceptar decisiones sobre la solicitud.
enum _ClosedReason { window, year }

/// Detalle de una solicitud para el autorizador: ✓ o ✕ en la fila de cada
/// persona (investir sin comentario, o rechazar con un motivo) y una
/// confirmación que dice exactamente qué se envía. Quien queda sin decidir
/// sigue en espera. El motivo humano de un rechazo nunca se muestra aquí.
class AuthorizerRequestDetailView extends ConsumerStatefulWidget {
  const AuthorizerRequestDetailView({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<AuthorizerRequestDetailView> createState() =>
      _AuthorizerRequestDetailViewState();
}

class _AuthorizerRequestDetailViewState
    extends ConsumerState<AuthorizerRequestDetailView> {
  final Map<String, DecisionChoice> _decisions = {};
  InvestitureResolution? _result;
  _ClosedReason? _closed;

  String get _requestId => widget.requestId;

  Future<void> _refresh() async {
    ref.invalidate(authorizerRequestProvider(_requestId));
    try {
      await ref.read(authorizerRequestProvider(_requestId).future);
    } catch (_) {
      // El error se pinta desde el estado del provider.
    }
  }

  String _nameOf(RequestPerson person) =>
      person.userName?.trim().isNotEmpty ?? false
          ? person.userName!.trim()
          : tr('investiture_requests.section.unnamed_person');

  void _toggleInvest(RequestPerson person) => setState(() {
        if (_decisions[person.personId] is InvestChoice) {
          _decisions.remove(person.personId);
        } else {
          _decisions[person.personId] = const InvestChoice();
        }
      });

  Future<void> _reject(RequestPerson person) async {
    final current = _decisions[person.personId];
    final reason = await showRejectReasonSheet(
      context,
      personName: _nameOf(person),
      className: person.className,
      initialReason: current is RejectChoice ? current.reason : null,
    );
    if (!mounted) return;
    setState(() {
      if (reason == null) {
        _decisions.remove(person.personId);
      } else {
        _decisions[person.personId] = RejectChoice(reason: reason);
      }
    });
  }

  void _investAll(List<RequestPerson> decidable) => setState(() {
        for (final person in decidable) {
          if (_decisions[person.personId] is! RejectChoice) {
            _decisions[person.personId] = const InvestChoice();
          }
        }
      });

  Future<void> _confirm(List<RequestPerson> decidable) async {
    final invest = <InvestDecision>[];
    final reject = <RejectDecision>[];
    for (final person in decidable) {
      switch (_decisions[person.personId]) {
        case InvestChoice():
          invest.add(InvestDecision(personId: person.personId));
        case RejectChoice(:final reason):
          reject.add(RejectDecision(personId: person.personId, reason: reason));
        case null:
          break;
      }
    }
    if (invest.isEmpty && reject.isEmpty) return;

    final confirmed = await SacDialog.show(
      context,
      title: tr('$_i18n.confirm_title'),
      content: tr(
        '$_i18n.confirm_body',
        namedArgs: {'invest': '${invest.length}', 'reject': '${reject.length}'},
      ),
      confirmLabel: tr('$_i18n.confirm_action'),
      cancelLabel: tr('$_i18n.confirm_review'),
    );
    if (confirmed != true || !mounted) return;

    final notifier = ref.read(resolveNotifierProvider(_requestId).notifier);
    final ok = await notifier.submit(invest: invest, reject: reject);
    if (!mounted) return;

    final state = ref.read(resolveNotifierProvider(_requestId));
    if (ok) {
      setState(() {
        _decisions.clear();
        _result = state.resolution;
      });
      return;
    }

    final closed = _closedReasonOf(state.errorCode);
    if (closed != null) {
      setState(() {
        _closed = closed;
        _decisions.clear();
      });
    } else {
      SacSnackBar.show(
        context,
        state.errorMessage ?? tr('investiture_requests.errors.generic'),
        isError: true,
      );
      // La solicitud pudo cambiar (p. ej. otra persona ya resolvió): recarga.
      ref.invalidate(authorizerRequestProvider(_requestId));
    }
  }

  /// Cierre de ventana o de año según el código de negocio del error.
  _ClosedReason? _closedReasonOf(String? errorCode) => switch (errorCode) {
        investitureWindowClosedCode => _ClosedReason.window,
        investitureYearClosedCode => _ClosedReason.year,
        _ => null,
      };

  void _backToList() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RouteNames.investitureAuthorize);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final requestAsync = ref.watch(authorizerRequestProvider(_requestId));
    // Mantiene vivo el notifier mientras exista la pantalla.
    final busy = ref.watch(resolveNotifierProvider(_requestId)).isLoading;
    final request = requestAsync.value;
    final club = request?.clubName?.trim();

    final Widget body;
    if (request == null) {
      body = requestAsync.hasError
          ? InvestitureMessageState.loadError(
              title: tr('$_i18n.detail_load_error_title'),
              error: requestAsync.error,
              onRetry: _refresh,
            )
          : const InvestitureListSkeleton(rows: 5);
    } else {
      body = _body(context, request, busy: busy);
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.canvas,
      appBar: SacTopBar(
        title: club == null || club.isEmpty ? tr('$_i18n.detail_title') : club,
        backgroundColor: c.canvas,
        frosted: true,
      ),
      body: SacFrostedVeil(child: body),
    );
  }

  Widget _body(
    BuildContext context,
    InvestitureRequest request, {
    required bool busy,
  }) {
    final c = context.sac;
    final result = _result;
    if (result != null) {
      return Stack(
        children: [
          ListView(
            padding: SacTopBar.paddingBelowBar(
              context,
              const EdgeInsets.only(bottom: InvestitureFooter.height),
            ),
            children: [
              AuthorizerResult(
                resolution: result,
                request: request,
                subtitle: _subtitle(context, request),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: InvestitureFooter(
              button: SacButton.primary(
                text: tr('$_i18n.result.back'),
                onPressed: _backToList,
              ),
            ),
          ),
        ],
      );
    }

    final pending = request.pendingPeople;
    final resolved = request.people
        .where((p) => p.status != PersonStatus.pending)
        .toList(growable: false);
    final canDecide = _closed == null;
    final decidable = pending.where((p) => p.canAuthorize).toList();
    final invest =
        decidable.where((p) => _decisions[p.personId] is InvestChoice).length;
    final reject =
        decidable.where((p) => _decisions[p.personId] is RejectChoice).length;
    final undecided = decidable.length - invest - reject;
    final showFooter = canDecide && decidable.isNotEmpty;

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
              if (_closed != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: SacSummaryBox(
                    color: c.warningContainer,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildIcon(
                          _closed == _ClosedReason.window
                              ? HugeIcons.strokeRoundedCalendarLock01
                              : HugeIcons.strokeRoundedLockKey,
                          size: 20,
                          color: c.onWarningContainer,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            tr(
                              _closed == _ClosedReason.window
                                  ? '$_i18n.window_closed'
                                  : '$_i18n.year_closed',
                            ),
                            style: TextStyle(
                              fontSize: SacFontSize.bodyMedium,
                              height: 1.35,
                              color: c.onWarningContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (decidable.isNotEmpty)
                _DecisionSummary(
                  request: request,
                  label: _subtitle(context, request, includeClub: false),
                  total: decidable.length,
                  invest: invest,
                  reject: reject,
                  undecided: undecided,
                ),
              if (pending.isNotEmpty)
                SacGroupedSection(
                  key: const ValueKey('authorizer-detail-pending'),
                  label: tr('$_i18n.pending_title'),
                  count: pending.length,
                  action: canDecide && decidable.isNotEmpty
                      ? InvestitureEyebrowAction(
                          label: tr('$_i18n.invest_all'),
                          onTap: busy ? null : () => _investAll(decidable),
                        )
                      : null,
                  children: [
                    for (final person in pending)
                      _PendingRow(
                        person: person,
                        name: _nameOf(person),
                        decision: _decisions[person.personId],
                        interactive: canDecide && person.canAuthorize && !busy,
                        onInvest: () => _toggleInvest(person),
                        onReject: () => _reject(person),
                      ),
                  ],
                ),
              if (resolved.isNotEmpty)
                SacGroupedSection(
                  key: const ValueKey('authorizer-detail-resolved'),
                  label: tr('$_i18n.resolved_title'),
                  children: [
                    for (final person in resolved)
                      _ResolvedRow(person: person, name: _nameOf(person)),
                  ],
                ),
              if (pending.isEmpty && resolved.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: Text(
                    tr('$_i18n.no_people'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: SacFontSize.titleSmall,
                      color: c.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (showFooter)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: InvestitureFooter(
              button: SacButton.primary(
                text: tr(
                  '$_i18n.confirm_cta',
                  namedArgs: {'invest': '$invest', 'reject': '$reject'},
                ),
                isEnabled: invest + reject > 0 && !busy,
                isLoading: busy,
                onPressed: () => _confirm(decidable),
              ),
              note: undecided > 0
                  ? tr('$_i18n.undecided_note',
                      namedArgs: {'count': '$undecided'})
                  : tr('$_i18n.all_decided'),
            ),
          ),
      ],
    );
  }

  /// "Club · Sección · investidura sáb 14 dic" (con [includeClub]) o sin club.
  String _subtitle(
    BuildContext context,
    InvestitureRequest request, {
    bool includeClub = true,
  }) {
    final dates = request.pendingPeople.isNotEmpty
        ? request.pendingPeople.map((p) => civilDay(p.investitureDate))
        : request.people.map((p) => civilDay(p.investitureDate));
    final date = request.earliestInvestitureDate ??
        (dates.isEmpty ? null : dates.reduce((a, b) => a.isBefore(b) ? a : b));
    final club = request.clubName?.trim();
    return [
      if (includeClub && club != null && club.isNotEmpty) club,
      if (request.sectionName != null && request.sectionName!.isNotEmpty)
        request.sectionName!,
      if (date != null)
        tr(
          '$_i18n.detail_date',
          namedArgs: {'date': formatInvestitureShortDay(context, date)},
        ),
    ].join(' · ');
  }
}

/// Caja de resumen: cuántas decisiones lleva y quién envió la solicitud.
class _DecisionSummary extends StatelessWidget {
  const _DecisionSummary({
    required this.request,
    required this.label,
    required this.total,
    required this.invest,
    required this.reject,
    required this.undecided,
  });

  final InvestitureRequest request;
  final String label;
  final int total;
  final int invest;
  final int reject;
  final int undecided;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final sender = request.createdBy?.name;
    final sentAt = request.createdAt;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: SacSummaryBox(
        color: c.surfaceVariant,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label.isNotEmpty)
              Text(
                label,
                style: TextStyle(
                  fontSize: SacFontSize.bodySmall,
                  fontWeight: FontWeight.w600,
                  color: c.textSecondary,
                ),
              ),
            const SizedBox(height: 2),
            Text.rich(
              key: const ValueKey('authorizer-decided'),
              TextSpan(
                children: [
                  TextSpan(
                    text: tr(
                      '$_i18n.decided_of_total',
                      namedArgs: {
                        'decided': '${invest + reject}',
                        'total': '$total',
                      },
                    ),
                    style: TextStyle(
                      fontSize: SacFontSize.displayMedium,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                      color: c.text,
                    ),
                  ),
                  TextSpan(
                    text: '  ·  ${tr('$_i18n.decided_suffix')}',
                    style: TextStyle(
                      fontSize: SacFontSize.bodyMedium,
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SacStatusBar(
              segments: [
                SacStatusSegment(
                  count: invest,
                  color: c.success,
                  label: tr('$_i18n.legend_invest',
                      namedArgs: {'count': '$invest'}),
                ),
                SacStatusSegment(
                  count: reject,
                  color: c.error,
                  label: tr('$_i18n.legend_reject',
                      namedArgs: {'count': '$reject'}),
                ),
                SacStatusSegment(
                  count: undecided,
                  color: c.textTertiary.withValues(alpha: 0.45),
                  label: tr(
                    '$_i18n.legend_undecided',
                    namedArgs: {'count': '$undecided'},
                  ),
                ),
              ],
            ),
            if (sender != null) ...[
              const SizedBox(height: 14),
              Divider(height: 1, thickness: 1, color: c.border),
              const SizedBox(height: 12),
              Row(
                children: [
                  buildIcon(
                    HugeIcons.strokeRoundedUserGroup,
                    size: 15,
                    color: c.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      sentAt == null
                          ? tr('$_i18n.sent_by', namedArgs: {'name': sender})
                          : tr(
                              '$_i18n.sent_by_on',
                              namedArgs: {
                                'name': sender,
                                'date': formatInvestitureDate(
                                  context,
                                  sentAt.toLocal(),
                                ),
                              },
                            ),
                      style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        color: c.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({
    required this.person,
    required this.name,
    required this.decision,
    required this.interactive,
    required this.onInvest,
    required this.onReject,
  });

  final RequestPerson person;
  final String name;
  final DecisionChoice? decision;
  final bool interactive;
  final VoidCallback onInvest;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final rejected = decision is RejectChoice;
    final className = person.className ?? '';

    return InvestitureRow(
      leading: InvestitureAvatar(name: name),
      title: name,
      detail: rejected ? tr('$_i18n.reject_with_reason') : className,
      detailColor: rejected ? c.onErrorContainer : null,
      trailing: person.canAuthorize
          ? _DecisionToggle(
              personId: person.personId,
              name: name,
              decision: decision,
              enabled: interactive,
              onInvest: onInvest,
              onReject: onReject,
            )
          : SacBadge.info(
              label: tr('$_i18n.waiting'),
              icon: HugeIcons.strokeRoundedClock01,
            ),
    );
  }
}

/// ✕ / ✓ de la fila. Cada botón mide 44 de alto y de ancho; el color nunca es
/// el único indicador: el seleccionado además lleva el ícono relleno.
class _DecisionToggle extends StatelessWidget {
  const _DecisionToggle({
    required this.personId,
    required this.name,
    required this.decision,
    required this.enabled,
    required this.onInvest,
    required this.onReject,
  });

  final String personId;
  final String name;
  final DecisionChoice? decision;
  final bool enabled;
  final VoidCallback onInvest;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    Widget button({
      required HugeIconData icon,
      required bool selected,
      required Color selectedBackground,
      required Color selectedForeground,
      required String label,
      required VoidCallback onTap,
      Key? key,
    }) {
      return Semantics(
        button: true,
        selected: selected,
        enabled: enabled,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          key: key,
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusXS),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? selectedBackground : Colors.transparent,
              borderRadius: BorderRadius.circular(AppTheme.radiusXS),
            ),
            child: buildIcon(
              icon,
              size: 18,
              color: selected ? selectedForeground : c.textTertiary,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(AppTheme.radiusSM - 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(
            key: ValueKey('reject-$personId'),
            icon: HugeIcons.strokeRoundedCancel01,
            selected: decision is RejectChoice,
            selectedBackground: c.error,
            selectedForeground: c.onError,
            label: tr('$_i18n.reject_person', namedArgs: {'name': name}),
            onTap: onReject,
          ),
          button(
            key: ValueKey('invest-$personId'),
            icon: HugeIcons.strokeRoundedTick02,
            selected: decision is InvestChoice,
            selectedBackground: c.success,
            selectedForeground: c.onSuccess,
            label: tr('$_i18n.invest_person', namedArgs: {'name': name}),
            onTap: onInvest,
          ),
        ],
      ),
    );
  }
}

class _ResolvedRow extends StatelessWidget {
  const _ResolvedRow({required this.person, required this.name});

  final RequestPerson person;
  final String name;

  @override
  Widget build(BuildContext context) {
    final SacBadge? badge = switch (person.status) {
      PersonStatus.invested => SacBadge.success(
          label: tr('investiture_requests.history.status_invested'),
        ),
      PersonStatus.rejectedByPerson || PersonStatus.rejected => SacBadge.error(
          label: tr('investiture_requests.history.status_not_invested'),
        ),
      PersonStatus.rejectedBySystem => SacBadge.error(
          label: tr('$_i18n.status_rejected_by_system'),
        ),
      PersonStatus.removed => SacBadge(
          label: tr('$_i18n.status_removed'),
          variant: SacBadgeVariant.neutral,
        ),
      PersonStatus.closedYear => SacBadge.warning(
          label: tr('investiture_requests.history.status_closed_year'),
        ),
      _ => null,
    };

    // El texto largo solo existe cuando decidió el sistema; el motivo humano
    // de un rechazo no se lee nunca en esta pantalla.
    final systemNote = person.status == PersonStatus.rejectedBySystem
        ? person.systemReason?.trim()
        : null;
    final decidedBy = person.resolvedByName?.trim();
    final detail = [
      if (person.className != null) person.className!,
      formatInvestitureDate(context, person.investitureDate),
      if (decidedBy != null && decidedBy.isNotEmpty)
        tr('$_i18n.decided_by', namedArgs: {'name': decidedBy}),
      if (systemNote != null && systemNote.isNotEmpty) systemNote,
    ].join(' · ');

    return InvestitureRow(
      leading: InvestitureAvatar(name: name, muted: true),
      title: name,
      detail: detail,
      detailMaxLines: 3,
      trailing: badge,
    );
  }
}
