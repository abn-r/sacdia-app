import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';

import '../../domain/entities/member_of_month.dart';
import '../providers/units_providers.dart';

/// Pantalla de historial del Miembro del Mes para una sección.
///
/// Lista cronológica (más reciente primero) con scroll infinito.
/// Cada entrada muestra: mes/año, avatar, nombre y puntos.
/// Los empates se agrupan bajo el mismo mes/año.
class MemberOfMonthHistoryView extends ConsumerStatefulWidget {
  final int clubId;
  final int sectionId;

  const MemberOfMonthHistoryView({
    super.key,
    required this.clubId,
    required this.sectionId,
  });

  @override
  ConsumerState<MemberOfMonthHistoryView> createState() =>
      _MemberOfMonthHistoryViewState();
}

class _MemberOfMonthHistoryViewState
    extends ConsumerState<MemberOfMonthHistoryView> {
  final _scrollController = ScrollController();

  MemberOfMonthHistoryParams get _params => MemberOfMonthHistoryParams(
        clubId: widget.clubId,
        sectionId: widget.sectionId,
      );

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final state = ref.read(memberOfMonthHistoryProvider(_params));
    if (state.isLoading || !state.hasMore) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    // Cargar más cuando queden 150px para el final
    if (currentScroll >= maxScroll - 150) {
      ref
          .read(memberOfMonthHistoryProvider(_params).notifier)
          .fetchNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final historyState = ref.watch(memberOfMonthHistoryProvider(_params));

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: const Text('Miembro del Mes — Historial'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(context, c, historyState),
    );
  }

  Widget _buildBody(
    BuildContext context,
    SacColors c,
    MemberOfMonthHistoryState historyState,
  ) {
    // Cargando primera página
    if (historyState.isLoading && historyState.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Error en primera carga
    if (historyState.errorMessage != null && historyState.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedAlertDiamond,
                size: 48,
                color: c.textTertiary,
              ),
              const SizedBox(height: 16),
              Text(
                historyState.errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: c.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    // Lista vacía
    if (historyState.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedTrophy,
              size: 64,
              color: c.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'No hay datos de miembro del mes aun.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: c.textSecondary,
                  ),
            ),
          ],
        ),
      );
    }

    // Lista con scroll infinito
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: historyState.items.length + 1, // +1 para el footer de carga
      itemBuilder: (context, index) {
        // Footer: indicador de carga o fin de lista
        if (index == historyState.items.length) {
          if (historyState.isLoading) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (!historyState.hasMore && historyState.items.isNotEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No hay mas registros',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: c.textTertiary,
                      ),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        }

        final entry = historyState.items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _MonthEntry(memberOfMonth: entry),
        );
      },
    );
  }
}

// ── Subwidgets ────────────────────────────────────────────────────────────────

/// Sección de un mes/año con sus ganadores (puede ser empate).
class _MonthEntry extends StatelessWidget {
  final MemberOfMonth memberOfMonth;

  const _MonthEntry({required this.memberOfMonth});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header del mes
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4A017),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${memberOfMonth.monthName} ${memberOfMonth.year}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: c.text,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (memberOfMonth.members.length > 1) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4A017).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Empate',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFFB8860B),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Cards de ganadores (una por cada miembro en empate)
        ...memberOfMonth.members.map((member) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _WinnerCard(member: member),
            )),
      ],
    );
  }
}

/// Card individual de un ganador del mes.
class _WinnerCard extends StatelessWidget {
  final MemberOfMonthEntry member;

  const _WinnerCard({required this.member});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return SacCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Avatar
          _WinnerAvatar(member: member),
          const SizedBox(width: 14),

          // Nombre + puntos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: c.text,
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedStar,
                      size: 13,
                      color: Color(0xFFD4A017),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${member.totalPoints} puntos',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: c.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Trofeo decorativo
          const HugeIcon(
            icon: HugeIcons.strokeRoundedTrophy,
            size: 22,
            color: Color(0xFFD4A017),
          ),
        ],
      ),
    );
  }
}

class _WinnerAvatar extends StatelessWidget {
  final MemberOfMonthEntry member;

  const _WinnerAvatar({required this.member});

  @override
  Widget build(BuildContext context) {
    if (member.photoUrl != null && member.photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: CachedNetworkImageProvider(member.photoUrl!),
      );
    }
    final initials = _initials(member.name);
    return CircleAvatar(
      radius: 24,
      backgroundColor: const Color(0xFFD4A017).withValues(alpha: 0.2),
      child: Text(
        initials,
        style: const TextStyle(
          color: Color(0xFFB8860B),
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
