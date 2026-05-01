// Widget conectado a datos reales via Riverpod.
//
// Envuelve [RoadmapScreen] (stateless, recibe tracks) con los estados
// loading / error / empty / data provenientes de [roadmapTracksProvider].

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/features/classes/presentation/roadmap/theme/roadmap_tokens.dart';

import '../../providers/classes_providers.dart';
import '../../views/class_detail_with_progress_view.dart';
import '../data/roadmap_data.dart';
import '../providers/roadmap_providers.dart';
import 'roadmap_screen.dart';

/// Versión conectada del roadmap de clases.
///
/// Consume [roadmapTracksProvider], gestiona loading / error / empty states
/// y navega a [ClassDetailWithProgressView] al tocar una clase inscrita.
///
/// Úsalo en [ClassesTabsView] en lugar de [RoadmapScreen] directamente.
class RoadmapScreenConnected extends ConsumerWidget {
  const RoadmapScreenConnected({super.key});

  void _onClassTap(BuildContext context, ClassItem item) {
    // Solo navegar si la clase está inscrita (current o done).
    // Las clases locked no tienen detail view accesible.
    if (item.status == ClassStatus.locked) return;

    final classId = int.tryParse(item.id);
    if (classId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClassDetailWithProgressView(classId: classId),
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
        onRetry: () {
          // Invalidar también los providers subyacentes para forzar un
          // nuevo fetch de red cuando el usuario toca "Reintentar".
          ref.invalidate(allClassesProvider);
          ref.invalidate(userClassesProvider);
          ref.invalidate(roadmapTracksProvider);
        },
        c: c,
      ),
      data: (tracks) {
        if (tracks.isEmpty) {
          return _EmptyState(c: c);
        }
        return RoadmapScreen(
          tracks: tracks,
          onClassTap: (item) => _onClassTap(context, item),
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
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedAlert02,
                  size: 56,
                  color: AppColors.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'classes.list.error_loading'.tr(),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString().replaceFirst('Exception: ', ''),
                  style: TextStyle(fontSize: 14, color: c.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SacButton.primary(
                  text: 'common.retry'.tr(),
                  icon: HugeIcons.strokeRoundedRefresh,
                  onPressed: onRetry,
                ),
              ],
            ),
          ),
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
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedSchool,
                size: 56,
                color: c.textTertiary,
              ),
              const SizedBox(height: 12),
              Text(
                'classes.list.empty'.tr(),
                style: TextStyle(fontSize: 16, color: c.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
