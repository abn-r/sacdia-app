import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/club_role_names.dart';
import '../../../../core/config/route_names.dart';
import '../../../../providers/catalogs_provider.dart';
import '../../../members/presentation/providers/members_providers.dart';
import '../../domain/entities/award_tier.dart';
import '../providers/section_ranking_provider.dart';
import '../widgets/member_ranking_list_tile.dart';
import '../widgets/ranking_empty_state.dart';
import '../widgets/ranking_skeleton.dart';

// ── Role helpers ──────────────────────────────────────────────────────────────

bool _canViewSectionRanking(String? role) {
  if (role == null) return false;
  return ClubRoleNames.sectionRankingViewers
      .contains(role.trim().toLowerCase());
}

// ── Screen ────────────────────────────────────────────────────────────────────

/// Pantalla de ranking de miembros dentro de una sección específica.
///
/// Flujo:
/// 1. Resuelve el año eclesiástico activo via [currentEcclesiasticalYearProvider].
/// 2. Valida el rol del usuario via [clubContextProvider] (RBAC client-side).
/// 3. Observa [sectionMembersProvider] con (sectionId, yearId).
/// 4. Renderiza lista de [MemberRankingListTile] con pull-to-refresh.
///
/// Navegación: accesible via `Navigator.push(context, MaterialPageRoute(...))`
/// hasta que una tarea futura integre la pantalla en el nav principal.
class SectionRankingScreen extends ConsumerWidget {
  const SectionRankingScreen({super.key, required this.sectionId});

  /// ID de la sección cuyo ranking se muestra.
  final int sectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yearAsync = ref.watch(currentEcclesiasticalYearProvider);
    final ctxAsync = ref.watch(clubContextProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr('rankings.section_ranking.title'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            // Subtítulo: se sobreescribe con el yearLabel cuando está disponible.
            // Mientras carga, muestra el texto base.
            yearAsync.maybeWhen(
              data: (year) => Text(
                year != null
                    ? tr('rankings.section_ranking.subtitle_with_year',
                        namedArgs: {'year': year.name})
                    : tr('rankings.section_ranking.subtitle'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
              orElse: () => Text(
                tr('rankings.section_ranking.subtitle'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
        toolbarHeight: 60,
      ),
      body: yearAsync.when(
        data: (year) {
          if (year == null) {
            return const RankingEmptyState(reason: RankingEmptyReason.noData);
          }

          // RBAC gate: validar rol antes de mostrar datos.
          // ctxAsync puede estar loading → usamos valueOrNull para no bloquear.
          final ctx = ctxAsync.valueOrNull;
          if (ctx == null || !_canViewSectionRanking(ctx.roleName)) {
            // ctx == null puede ser transitorio (aún cargando) o definitivo
            // (sin grant activo). Cuando ctxAsync aún está cargando,
            // mostramos el skeleton — evita un flash de "sin datos".
            if (ctxAsync.isLoading) {
              return RankingSkeleton.sectionList();
            }
            return const RankingEmptyState(
                reason: RankingEmptyReason.unauthorized);
          }

          return _buildList(context, ref, year.ecclesiasticalYearId);
        },
        loading: () => RankingSkeleton.sectionList(),
        error: (_, __) => RankingEmptyState(
          reason: RankingEmptyReason.networkError,
          onRetry: () => ref.invalidate(currentEcclesiasticalYearProvider),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, int yearId) {
    final params = (sectionId: sectionId, yearId: yearId);
    final membersAsync = ref.watch(sectionMembersProvider(params));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(sectionMembersProvider(params)),
      child: membersAsync.when(
        data: (members) {
          if (members.isEmpty) {
            return const SingleChildScrollView(
              // ScrollView necesario para que RefreshIndicator funcione.
              physics: AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: 500,
                child: RankingEmptyState(
                    reason: RankingEmptyReason.noSectionMembers),
              ),
            );
          }

          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: members.length,
            separatorBuilder: (_, __) => const Divider(
              indent: 60, // 16 outer-padding + 32 rank-col + 12 gap
              height: 1,
            ),
            itemBuilder: (_, i) {
              final m = members[i];
              return MemberRankingListTile(
                key: ValueKey(m.enrollmentId),
                rankPosition: m.rankPosition ?? (i + 1),
                memberName: m.memberName,
                sectionName: m.sectionName,
                compositeScore: m.compositeScorePct,
                awardedCategoryName: m.awardedCategory?.name,
                awardedCategoryTier:
                    m.awardedCategory?.tier ?? AwardTier.unknown,
                onTap: () => context.push(
                  RouteNames.memberBreakdownPath(m.enrollmentId, yearId),
                ),
              );
            },
          );
        },
        loading: () => RankingSkeleton.sectionList(),
        error: (_, __) => RankingEmptyState(
          reason: RankingEmptyReason.networkError,
          onRetry: () => ref.invalidate(sectionMembersProvider(params)),
        ),
      ),
    );
  }
}
