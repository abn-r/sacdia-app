import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/catalogs_provider.dart';
import '../../../members/presentation/providers/members_providers.dart';
import '../providers/section_ranking_provider.dart';
import '../widgets/member_ranking_list_tile.dart';
import '../widgets/ranking_empty_state.dart';
import '../widgets/ranking_skeleton.dart';

// ── Role helpers ──────────────────────────────────────────────────────────────

/// Roles autorizados a ver el ranking de sección.
///
/// Equivalente al conjunto de [_kManagementRoles] de units_list_view.dart
/// más 'counselor' — los counselors son responsables de su unidad y
/// necesitan visibilidad del ranking para hacer seguimiento.
const _kSectionRankingRoles = [
  'director',
  'sub_director',
  'secretario',
  'secretario_tesorero',
  'counselor',
];

bool _canViewSectionRanking(String? role) {
  if (role == null) return false;
  return _kSectionRankingRoles.contains(role.trim().toLowerCase());
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
            const Text(
              'Ranking de sección',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            // Subtítulo: se sobreescribe con el yearLabel cuando está disponible.
            // Mientras carga, muestra el texto base.
            yearAsync.maybeWhen(
              data: (year) => Text(
                year != null
                    ? 'Registro de progreso — ${year.name}'
                    : 'Registro de progreso',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
              orElse: () => const Text(
                'Registro de progreso',
                style: TextStyle(
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
                awardedCategoryTierId: m.awardedCategory?.id,
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
