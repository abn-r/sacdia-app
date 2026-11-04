import 'package:easy_localization/easy_localization.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
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
      extendBodyBehindAppBar: true,
      appBar: SacTopBar(
          title: 'master_honors.title'.tr(), centerTitle: true, frosted: true),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) {
            final top = SacTopBar.frostedInset(context);
            return roadmapAsync.when(
              loading: () => Padding(
                padding: EdgeInsets.only(top: top),
                child: const Center(child: SacLoading()),
              ),
              error: (_, __) => Padding(
                padding: EdgeInsets.only(top: top),
                child: SacErrorState(
                  title: 'master_honors.load_error_title'.tr(),
                  message: 'master_honors.load_error_body'.tr(),
                  onRetry: () => ref.invalidate(userMasterHonorRoadmapProvider),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.only(top: top),
                    child: const _EmptyState(),
                  );
                }

                return RefreshIndicator(
                  color: SacAccent.of(context).color,
                  backgroundColor: context.sac.surface,
                  edgeOffset: top,
                  onRefresh: () async {
                    ref.invalidate(userMasterHonorRoadmapProvider);
                    await ref.read(userMasterHonorRoadmapProvider.future);
                  },
                  child: MasterHonorRoadmapGrid(
                    items: items,
                    padding: EdgeInsets.fromLTRB(16, top, 16, 24),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return SacEmptyState(
      icon: HugeIcons.strokeRoundedAward01,
      title: 'master_honors.empty_title'.tr(),
    );
  }
}
