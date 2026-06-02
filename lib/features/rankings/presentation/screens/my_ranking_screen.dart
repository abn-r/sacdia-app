import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../features/auth/domain/utils/authorization_utils.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../providers/catalogs_provider.dart';
import '../../domain/entities/award_tier.dart';
import '../../domain/entities/member_ranking.dart';
import '../providers/my_ranking_provider.dart';
import '../widgets/ranking_empty_state.dart';
import '../widgets/ranking_hero_card.dart';
import '../widgets/ranking_skeleton.dart';
import '../widgets/signal_score_row.dart';
import '../widgets/top_n_section.dart';

/// Pantalla principal de ranking individual del miembro.
///
/// Flujo:
/// 1. Resuelve el año eclesiástico activo via [currentEcclesiasticalYearProvider].
/// 2. Con el yearId, observa [myRankingProvider] para obtener [MyRankingView?].
/// 3. null → visibility=hidden → [RankingEmptyState.hidden].
/// 4. Datos → layout completo con hero card, señales y top-N condicional.
///
/// Navegación: accesible via Navigator.push directo hasta que Task 26+
/// integre ambas pantallas en el nav principal.
class MyRankingScreen extends ConsumerWidget {
  const MyRankingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Deep-link / hot-restart defense: if the user arrives here without the
    // required permission (e.g., via a push notification link or direct URL),
    // show a friendly empty state instead of a raw 403 from the backend.
    final user = ref.watch(
      authNotifierProvider.select((v) => v.valueOrNull),
    );
    if (!canViewMyRanking(user)) {
      return Scaffold(
        appBar: AppBar(
          title: Text(tr('rankings.my_ranking.title')),
        ),
        body: const Center(
          child: RankingEmptyState(reason: RankingEmptyReason.unauthorized),
        ),
      );
    }

    final yearAsync = ref.watch(currentEcclesiasticalYearProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('rankings.my_ranking.title')),
      ),
      body: yearAsync.when(
        data: (year) {
          if (year == null) {
            return const RankingEmptyState(reason: RankingEmptyReason.noData);
          }
          return _RankingBody(
            yearId: year.ecclesiasticalYearId,
            yearLabel: year.name,
          );
        },
        loading: () => RankingSkeleton.myRanking(),
        error: (_, __) => RankingEmptyState(
          reason: RankingEmptyReason.networkError,
          onRetry: () => ref.invalidate(currentEcclesiasticalYearProvider),
        ),
      ),
    );
  }
}

/// Cuerpo principal que ya tiene el yearId resuelto.
class _RankingBody extends ConsumerWidget {
  final int yearId;
  final String yearLabel;

  const _RankingBody({required this.yearId, required this.yearLabel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myRankingAsync = ref.watch(myRankingProvider(yearId));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(myRankingProvider(yearId)),
      child: myRankingAsync.when(
        data: (view) {
          // null = visibility=hidden → silenciar con mensaje calmo.
          if (view == null) {
            return const SingleChildScrollView(
              // ScrollView necesario para que RefreshIndicator funcione.
              physics: AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: 500,
                child: RankingEmptyState(reason: RankingEmptyReason.hidden),
              ),
            );
          }

          // Sin datos de member (score aún no calculado).
          if (view.member == null) {
            return const SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: 500,
                child: RankingEmptyState(reason: RankingEmptyReason.noData),
              ),
            );
          }

          final ranking = view.member!;

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Hero card con puntaje compuesto.
              // Tapping navigates to the full breakdown drill-down.
              SliverToBoxAdapter(
                child: GestureDetector(
                  onTap: () => context.push(
                    RouteNames.memberBreakdownPath(
                        ranking.enrollmentId, yearId),
                  ),
                  child: RankingHeroCard(
                    compositeScore: ranking.compositeScorePct,
                    rankPosition: ranking.rankPosition,
                    totalInSection: _resolveTotalInSection(view),
                    awardedCategoryName: ranking.awardedCategory?.name,
                    awardedCategoryTier:
                        ranking.awardedCategory?.tier ?? AwardTier.unknown,
                    sectionName: ranking.sectionName,
                    ecclesiasticalYearLabel: yearLabel,
                  ),
                ),
              ),

              // Fila de señales.
              SliverPadding(
                padding: EdgeInsets.zero,
                sliver: SliverToBoxAdapter(
                  child: SignalScoreRow(
                    classScore: ranking.classScorePct,
                    investitureScore: ranking.investitureScorePct,
                    camporeeScore: ranking.camporeeScorePct,
                  ),
                ),
              ),

              // Nudge contextual basado en la señal más baja.
              SliverToBoxAdapter(
                child: _ContextualNudge(ranking: ranking),
              ),

              // Top-N (solo si visibility = selfAndTopN y topN no está vacío).
              if (view.visibilityMode == MyRankingVisibilityMode.selfAndTopN &&
                  view.topN != null &&
                  view.topN!.isNotEmpty)
                SliverToBoxAdapter(
                  child: TopNSection(
                    entries: view.topN!,
                    userOwnRankPosition: ranking.rankPosition,
                    userOwnComposite: ranking.compositeScorePct,
                  ),
                ),

              // Espacio inferior para la última fila no quede pegada al borde.
              const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
            ],
          );
        },
        loading: () => RankingSkeleton.myRanking(),
        error: (_, __) => RankingEmptyState(
          reason: RankingEmptyReason.networkError,
          onRetry: () => ref.invalidate(myRankingProvider(yearId)),
        ),
      ),
    );
  }

  /// Resuelve el total de miembros en la sección a partir del top-N si
  /// está disponible. Fallback: null (la hero card omite la línea de rank).
  int? _resolveTotalInSection(MyRankingView view) {
    if (view.topN == null || view.topN!.isEmpty) return null;
    // El top-N no expone el total directamente; lo inferimos del último
    // rankPosition del listado si el backend lo envía ordenado.
    // Si el usuario está fuera del top-N, su propio rank es el indicador.
    final member = view.member;
    if (member?.rankPosition != null && view.topN!.isNotEmpty) {
      // Devolvemos null para no mostrar un total incorrecto. El backend
      // debería enviar total_in_section en una versión futura del contrato.
      return null;
    }
    return null;
  }
}

// ── Nudge contextual ────────────────────────────────────────────────────────

/// Muestra una línea de motivación derivada de la señal con puntaje más bajo.
///
/// Oculto si todas las señales son null.
class _ContextualNudge extends StatelessWidget {
  final MemberRanking ranking;

  const _ContextualNudge({required this.ranking});

  /// Devuelve la clave i18n correspondiente a la señal con menor puntaje no-null.
  String? _nudgeKey() {
    final scores = <String, double?>{
      'class': ranking.classScorePct,
      'investiture': ranking.investitureScorePct,
      'camporee': ranking.camporeeScorePct,
    };

    // Filtramos solo los que tienen valor.
    final available = scores.entries.where((e) => e.value != null).toList()
      ..sort((a, b) => a.value!.compareTo(b.value!));

    if (available.isEmpty) return null;

    switch (available.first.key) {
      case 'class':
        return 'rankings.my_ranking.nudge_class';
      case 'investiture':
        return 'rankings.my_ranking.nudge_investiture';
      case 'camporee':
        return 'rankings.my_ranking.nudge_camporee';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = _nudgeKey();
    if (key == null) return const SizedBox.shrink();

    final c = context.sac;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedArrowRight01,
            size: 12,
            color: c.textSecondary,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              tr(key),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: c.textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
