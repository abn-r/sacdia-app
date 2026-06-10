import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/features/master_honors/presentation/providers/master_honors_providers.dart';
import 'package:sacdia_app/features/master_honors/presentation/widgets/master_honor_roadmap_grid.dart';

/// Pantalla completa con el roadmap de maestrías.
///
/// El perfil solo muestra el resumen; esta vista concentra el listado completo
/// y el detalle de requisitos por maestría.
class MasterHonorsView extends ConsumerWidget {
  const MasterHonorsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roadmapAsync = ref.watch(userMasterHonorRoadmapProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        foregroundColor: context.sac.text,
        centerTitle: true,
        title: Text(
          'Maestrías',
          style: TextStyle(
            color: context.sac.text,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: context.sac.text,
            size: 22,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: roadmapAsync.when(
        loading: () => const Center(child: SacLoading()),
        error: (_, __) => _ErrorState(
          onRetry: () => ref.invalidate(userMasterHonorRoadmapProvider),
        ),
        data: (items) {
          if (items.isEmpty) return const _EmptyState();

          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: context.sac.surface,
            onRefresh: () async {
              ref.invalidate(userMasterHonorRoadmapProvider);
              await ref.read(userMasterHonorRoadmapProvider.future);
            },
            child: MasterHonorRoadmapGrid(items: items),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedAward01,
              size: 64,
              color: context.sac.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'Aún no hay maestrías disponibles.',
              style: TextStyle(
                color: context.sac.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
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
              'No pudimos cargar las maestrías',
              style: TextStyle(
                color: context.sac.text,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Intenta nuevamente en unos segundos.',
              style: TextStyle(
                color: context.sac.textSecondary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SacButton.primary(
              text: 'Reintentar',
              icon: HugeIcons.strokeRoundedRefresh,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
