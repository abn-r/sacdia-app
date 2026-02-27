import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/usecases/get_honors.dart';
import '../providers/honors_providers.dart';

/// Vista de detalle de honor - Estilo "Scout Vibrante"
///
/// Header con imagen/icono grande, nombre, categoría, nivel,
/// descripción, requisitos checklist, botón de acción.
class HonorDetailView extends ConsumerWidget {
  final int honorId;

  const HonorDetailView({
    super.key,
    required this.honorId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final honorAsync = ref.watch(honorsProvider(GetHonorsParams()));
    final authState = ref.watch(authNotifierProvider);
    final enrollmentState = ref.watch(honorEnrollmentNotifierProvider);

    return Scaffold(
      backgroundColor: context.sac.background,
      body: honorAsync.when(
        data: (honors) {
          final honor = honors.firstWhere(
            (h) => h.id == honorId,
            orElse: () => throw Exception('Especialidad no encontrada'),
          );

          return CustomScrollView(
            slivers: [
              // Header
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.accent,
                          AppColors.accentDark,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          // Honor icon
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: honor.imageUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Image.network(
                                      honor.imageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          HugeIcon(
                                        icon: HugeIcons.strokeRoundedAward01,
                                        size: 44,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                : HugeIcon(
                                    icon: HugeIcons.strokeRoundedAward01,
                                    size: 44,
                                    color: Colors.white,
                                  ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            honor.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          if (honor.skillLevel != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  HugeIcon(icon: HugeIcons.strokeRoundedStar,
                                      size: 14, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Nivel ${honor.skillLevel}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Body
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Description
                      if (honor.description != null) ...[
                        Row(
                          children: [
                            HugeIcon(icon: HugeIcons.strokeRoundedInformationCircle,
                                size: 20, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Descripción',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          honor.description!,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: context.sac.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Requirements
                      Row(
                        children: [
                          HugeIcon(icon: HugeIcons.strokeRoundedCheckList,
                              size: 20, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Requisitos',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SacCard(
                        backgroundColor: context.sac.surfaceVariant,
                        child: Text(
                          'Los requisitos específicos de esta especialidad se mostrarán aquí.',
                          style: TextStyle(
                            fontSize: 14,
                            color: context.sac.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Action button
                      enrollmentState.when(
                        data: (userHonor) {
                          if (userHonor != null) {
                            return SacCard(
                              backgroundColor: AppColors.secondaryLight,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                                      size: 20,
                                      color: AppColors.secondaryDark),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Ya estás inscrito',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.secondaryDark,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return SacButton.primary(
                            text: 'Iniciar este honor',
                            icon: HugeIcons.strokeRoundedAdd01,
                            onPressed: () async {
                              final userId = authState.value?.id;
                              if (userId == null) return;

                              await ref
                                  .read(honorEnrollmentNotifierProvider.notifier)
                                  .enrollInHonor(userId, honorId);

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        const Text('Inscripción exitosa'),
                                    backgroundColor: AppColors.secondary,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                                ref.invalidate(userHonorsProvider);
                              }
                            },
                          );
                        },
                        loading: () => const Center(child: SacLoading()),
                        error: (error, stack) => SacButton.primary(
                          text: 'Reintentar inscripción',
                          icon: HugeIcons.strokeRoundedRefresh,
                          onPressed: () async {
                            final userId = authState.value?.id;
                            if (userId == null) return;

                            await ref
                                .read(
                                    honorEnrollmentNotifierProvider.notifier)
                                .enrollInHonor(userId, honorId);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: SacLoading()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedAlert02,
                    size: 56, color: AppColors.error),
                const SizedBox(height: 16),
                Text('Error al cargar detalle',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 24),
                SacButton.primary(
                  text: 'Reintentar',
                  icon: HugeIcons.strokeRoundedRefresh,
                  onPressed: () {
                    ref.invalidate(honorsProvider);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
