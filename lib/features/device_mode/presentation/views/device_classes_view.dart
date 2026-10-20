import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_card.dart';
import '../../../../core/widgets/sac_empty_state.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_progress_bar.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../classes/presentation/providers/classes_providers.dart';

/// Clases del menor con su avance. Solo las que tienen inscripción propia; sin
/// inscribirse, ni buscar en el catálogo, ni honores (eso no es del teléfono).
///
/// Sin red, `userClassesProvider` sirve la última lista guardada en disco (solo
/// lectura).
class DeviceClassesView extends ConsumerWidget {
  const DeviceClassesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final classes = ref.watch(userClassesProvider);

    return Scaffold(
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'device.classes.title'.tr(),
        automaticallyImplyLeading: false,
      ),
      body: classes.when(
        loading: () => const Center(child: SacLoading()),
        error: (_, __) => SacEmptyState(
          key: const ValueKey('device_classes_error'),
          title: 'device.classes.error'.tr(),
          icon: HugeIcons.strokeRoundedAlert02,
          actionLabel: 'common.retry'.tr(),
          actionVariant: SacButtonVariant.outline,
          onAction: () => ref.invalidate(userClassesProvider),
        ),
        data: (list) {
          final enrolled = list.where((k) => k.enrollmentId != null).toList();
          if (enrolled.isEmpty) {
            return SacEmptyState(
              key: const ValueKey('device_classes_empty'),
              title: 'device.classes.empty_title'.tr(),
              body: 'device.classes.empty_body'.tr(),
              icon: HugeIcons.strokeRoundedCourse,
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(userClassesProvider);
              await ref.read(userClassesProvider.future);
            },
            child: ListView.builder(
              key: const ValueKey('device_classes_list'),
              padding: const EdgeInsets.all(16),
              itemCount: enrolled.length,
              itemBuilder: (context, index) {
                final klass = enrolled[index];
                final percent = (klass.overallProgress ?? 0).clamp(0, 100);
                final color = AppColors.classColor(klass.name);
                return SacCard(
                  key: ValueKey('device_class_${klass.id}'),
                  margin: const EdgeInsets.only(bottom: 12),
                  accentColor: color,
                  onTap: () => context.push(
                    RouteNames.deviceClassDetailPath(
                      klass.id,
                      enrollmentId: klass.enrollmentId,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        klass.name,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: c.text,
                                ),
                      ),
                      if (klass.ecclesiasticalYearLabel != null)
                        Text(
                          klass.ecclesiasticalYearLabel!,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: c.textSecondary,
                                  ),
                        ),
                      const SizedBox(height: 12),
                      SacProgressBar(progress: percent / 100),
                      const SizedBox(height: 6),
                      Text(
                        'device.classes.progress'
                            .tr(namedArgs: {'percent': '$percent'}),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: c.textSecondary,
                            ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
