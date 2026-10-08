import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/authorization/access_subject.dart';
import '../../../../core/authorization/screen_catalog.dart';
import '../../../../core/config/route_names.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_empty_state.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../../providers/catalogs_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/investiture_request.dart';
import '../providers/investiture_requests_providers.dart';
import '../widgets/authorizer_request_card.dart';
import '../widgets/investiture_message_state.dart';
import '../widgets/investiture_section_label.dart';

const _i18n = 'investiture_requests.authorizer';

/// Solicitudes de investidura que el usuario puede autorizar (pastor del
/// distrito, director o subdirector del Campo). Es el inicio del pastor sin
/// club y una entrada del acceso rápido de `director-lf`/`assistant-lf`.
class AuthorizerRequestsView extends ConsumerWidget {
  const AuthorizerRequestsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final user = ref.watch(authNotifierProvider.select((v) => v.valueOrNull));
    final allowed = canViewScreen(
      subjectFromUser(user),
      'app-investiture-authorizer',
    );
    final yearAsync = ref.watch(currentEcclesiasticalYearProvider);
    final year = yearAsync.valueOrNull;

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
            if (!allowed) {
              return InvestitureMessageState(
                title: tr('$_i18n.restricted_title'),
                body: tr('$_i18n.restricted_body'),
                icon: HugeIcons.strokeRoundedLockKey,
              );
            }
            if (year == null) {
              if (yearAsync.hasError) {
                return InvestitureMessageState(
                  title: tr('$_i18n.load_error_title'),
                  onRetry: () =>
                      ref.invalidate(currentEcclesiasticalYearProvider),
                );
              }
              return yearAsync.isLoading
                  ? const Center(child: SacLoading())
                  : InvestitureMessageState(
                      title: tr('$_i18n.no_year_title'),
                      body: tr('$_i18n.no_year_body'),
                      icon: HugeIcons.strokeRoundedCalendar03,
                    );
            }
            return _RequestsBody(yearId: year.ecclesiasticalYearId);
          },
        ),
      ),
    );
  }
}

class _RequestsBody extends ConsumerWidget {
  const _RequestsBody({required this.yearId});

  final int yearId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(authorizerRequestsProvider(yearId));

    Future<void> refresh() async {
      ref.invalidate(authorizerRequestsProvider(yearId));
      try {
        await ref.read(authorizerRequestsProvider(yearId).future);
      } catch (_) {
        // El error se pinta desde el estado del provider.
      }
    }

    final requests = requestsAsync.valueOrNull;
    if (requests == null) {
      if (requestsAsync.hasError) {
        return InvestitureMessageState(
          title: tr('$_i18n.load_error_title'),
          onRetry: refresh,
        );
      }
      return const Center(child: SacLoading());
    }

    final waiting = _sorted(requests.where(_hasPeopleWaiting));
    final rest = _sorted(requests.where((r) => !_hasPeopleWaiting(r)));

    return RefreshIndicator(
      color: SacAccent.of(context).color,
      onRefresh: refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: SacTopBar.paddingBelowBar(
          context,
          const EdgeInsets.fromLTRB(16, 16, 16, 32),
        ),
        children: [
          if (requests.isEmpty) ...[
            const SizedBox(height: 48),
            SacEmptyState(
              title: tr('$_i18n.empty_title'),
              body: tr('$_i18n.empty_body'),
              icon: HugeIcons.strokeRoundedMedal01,
            ),
          ] else ...[
            if (waiting.isNotEmpty) ...[
              InvestitureSectionLabel(
                title: tr('$_i18n.waiting_title'),
                count: waiting.length,
              ),
              const SizedBox(height: 10),
              ..._cards(context, waiting),
            ],
            if (rest.isNotEmpty) ...[
              if (waiting.isNotEmpty) const SizedBox(height: 20),
              InvestitureSectionLabel(
                title: tr('$_i18n.rest_title'),
                count: rest.length,
              ),
              const SizedBox(height: 10),
              ..._cards(context, rest),
            ],
          ],
        ],
      ),
    );
  }

  static bool _hasPeopleWaiting(InvestitureRequest request) =>
      (request.pendingCount ?? request.pendingPeople.length) > 0;

  /// Con personas en espera primero la fecha más próxima; sin fecha, al final.
  static List<InvestitureRequest> _sorted(Iterable<InvestitureRequest> items) {
    final list = items.toList();
    list.sort((a, b) {
      final dateA = a.earliestInvestitureDate;
      final dateB = b.earliestInvestitureDate;
      if (dateA != null && dateB != null) {
        final byDate = dateA.compareTo(dateB);
        if (byDate != 0) return byDate;
      } else if (dateA != null) {
        return -1;
      } else if (dateB != null) {
        return 1;
      }
      return (a.clubName ?? '').compareTo(b.clubName ?? '');
    });
    return list;
  }

  List<Widget> _cards(BuildContext context, List<InvestitureRequest> items) => [
        for (final request in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AuthorizerRequestCard(
              request: request,
              onTap: () => context.push(
                RouteNames.investitureAuthorizeDetailPath(request.requestId),
              ),
            ),
          ),
      ];
}
