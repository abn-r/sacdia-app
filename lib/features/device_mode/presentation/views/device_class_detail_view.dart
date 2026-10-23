import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_card.dart';
import '../../../../core/widgets/sac_empty_state.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_progress_bar.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../classes/domain/entities/class_module_detail.dart';
import '../../../classes/domain/entities/class_requirement.dart';
import '../../../classes/presentation/providers/classes_providers.dart';
import '../../../classes/presentation/widgets/requirement_status_badge.dart';

/// Una clase del menor: sus módulos y requisitos con el estado de cada uno.
/// Tocar un requisito abre la pantalla de evidencias.
///
/// Es una vista propia, sin las llamadas extra de la vista de adultos
/// (investidura, especialidades relacionadas): el teléfono solo lee lo que su
/// alcance permite.
class DeviceClassDetailView extends ConsumerWidget {
  const DeviceClassDetailView({
    super.key,
    required this.classId,
    this.enrollmentId,
  });

  final int classId;
  final int? enrollmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final query = ClassProgressQuery(
      classId: classId,
      enrollmentId: enrollmentId,
    );
    final async = ref.watch(classWithProgressProvider(query));

    return Scaffold(
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: async.valueOrNull?.name ?? 'device.classes.title'.tr(),
      ),
      body: async.when(
        loading: () => const Center(child: SacLoading()),
        error: (_, __) => SacEmptyState(
          key: const ValueKey('device_class_error'),
          title: 'device.classes.detail_error'.tr(),
          icon: HugeIcons.strokeRoundedAlert02,
          actionLabel: 'common.retry'.tr(),
          actionVariant: SacButtonVariant.outline,
          onAction: () => ref.invalidate(classWithProgressProvider(query)),
        ),
        data: (klass) {
          if (klass.modules.isEmpty) {
            return SacEmptyState(
              title: 'device.classes.no_requirements'.tr(),
              icon: HugeIcons.strokeRoundedCourse,
            );
          }
          return ListView(
            key: const ValueKey('device_class_detail'),
            padding: const EdgeInsets.all(16),
            children: [
              SacProgressBar(
                progress: ((klass.overallProgress ?? 0) / 100).clamp(0.0, 1.0),
                label: '${(klass.overallProgress ?? 0).clamp(0, 100)}%',
              ),
              const SizedBox(height: 16),
              for (final module in klass.modules)
                _ModuleCard(
                  module: module,
                  onOpen: (requirement) => context.push(
                    RouteNames.deviceRequirementPath(
                      classId,
                      requirement.id,
                      enrollmentId: enrollmentId,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.module, required this.onOpen});

  final ClassModuleDetail module;
  final ValueChanged<ClassRequirement> onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    return SacCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            module.name,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
          const SizedBox(height: 8),
          for (final requirement in module.requirements)
            InkWell(
              key: ValueKey('device_requirement_${requirement.id}'),
              onTap: () => onOpen(requirement),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        requirement.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(color: c.text),
                      ),
                    ),
                    const SizedBox(width: 8),
                    RequirementStatusBadge(status: requirement.status),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
