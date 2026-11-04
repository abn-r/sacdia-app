// Widget conectado a datos reales via Riverpod.
//
// Envuelve [RoadmapScreen] (stateless, recibe tracks) con los estados
// loading / error / empty / data provenientes de [roadmapTracksProvider].

import 'package:easy_localization/easy_localization.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/features/classes/presentation/roadmap/theme/roadmap_tokens.dart';

import '../../views/class_detail_with_progress_view.dart';
import '../data/roadmap_data.dart';
import '../providers/roadmap_providers.dart';
import 'roadmap_screen.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';

/// Versión conectada del roadmap de clases.
///
/// Consume [roadmapTracksProvider], gestiona loading / error / empty states
/// y navega a [ClassDetailWithProgressView] al tocar una clase inscrita.
///
/// Úsalo en [ClassesTabsView] en lugar de [RoadmapScreen] directamente.
class RoadmapScreenConnected extends ConsumerWidget {
  const RoadmapScreenConnected({super.key});

  void _onClassTap(BuildContext context, ClassItem item) {
    // Solo navegar si la clase tiene enrollment (completada, cursando, vencida).
    if (!item.status.canOpenDetail) return;

    final classId = int.tryParse(item.id);
    if (classId == null) return;

    Navigator.push(
      context,
      SacSharedAxisRoute(
        builder: (_) => ClassDetailWithProgressView(
          classId: classId,
          enrollmentId: item.enrollmentId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksAsync = ref.watch(roadmapTracksProvider);
    final c = context.sac;

    return tracksAsync.when(
      loading: () => _LoadingState(c: c),
      error: (error, _) => _ErrorState(
        error: error,
        onRetry: () => refreshRoadmap(ref),
        c: c,
      ),
      data: (tracks) {
        if (tracks.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => refreshRoadmap(ref),
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: _EmptyState(c: c),
                ),
              ),
            ),
          );
        }
        return RoadmapScreen(
          tracks: tracks,
          onClassTap: (item) => _onClassTap(context, item),
          onRefresh: () => refreshRoadmap(ref),
        );
      },
    );
  }
}

// ── States ────────────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  final SacColors c;
  const _LoadingState({required this.c});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.33, 0.66, 1.0],
                colors: [
                  RoadmapTokens.bgAvTop,
                  RoadmapTokens.bgAvBottom,
                  RoadmapTokens.bgCqBottom,
                  RoadmapTokens.bgGmBottom,
                ],
              ),
            ),
          ),
        ),
        const Center(child: SacLoading()),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  final SacColors c;

  const _ErrorState({
    required this.error,
    required this.onRetry,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.33, 0.66, 1.0],
                colors: [
                  RoadmapTokens.bgAvTop,
                  RoadmapTokens.bgAvBottom,
                  RoadmapTokens.bgCqBottom,
                  RoadmapTokens.bgGmBottom,
                ],
              ),
            ),
          ),
        ),
        SacErrorState(
          title: 'classes.list.error_loading'.tr(),
          message: userErrorMessage(error),
          onRetry: onRetry,
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final SacColors c;
  const _EmptyState({required this.c});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.33, 0.66, 1.0],
                colors: [
                  RoadmapTokens.bgAvTop,
                  RoadmapTokens.bgAvBottom,
                  RoadmapTokens.bgCqBottom,
                  RoadmapTokens.bgGmBottom,
                ],
              ),
            ),
          ),
        ),
        SacEmptyState(
          icon: HugeIcons.strokeRoundedSchool,
          title: 'classes.list.empty'.tr(),
        ),
      ],
    );
  }
}
