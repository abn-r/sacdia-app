import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_progress_ring.dart';

import '../providers/classes_providers.dart';
import 'class_modules_view.dart';

/// Vista de detalle de clase - Estilo "Scout Vibrante"
///
/// Header con gradiente indigo, SacProgressRing blanco,
/// descripción, botón "Ver Módulos".
class ClassDetailView extends ConsumerWidget {
  final int classId;

  const ClassDetailView({
    super.key,
    required this.classId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classDetailAsync = ref.watch(classDetailProvider(classId));

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: classDetailAsync.when(
        data: (progressiveClass) {
          return CustomScrollView(
            slivers: [
              // Gradient header with progress ring
              SliverAppBar(
                expandedHeight: 260,
                pinned: true,
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary,
                          AppColors.primaryDark,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          // Progress ring (white on color)
                          SacProgressRing(
                            progress: 0.0, // TODO: real progress
                            size: 120,
                            strokeWidth: 8,
                            color: Colors.white,
                            trackColor: Colors.white24,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '0%',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                ),
                                const Text(
                                  'progreso',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            progressiveClass.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Body content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (progressiveClass.description != null) ...[
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
                          progressiveClass.description!,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: AppColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],

                      // Modules button
                      SacButton.primary(
                        text: 'Ver Módulos',
                        icon: HugeIcons.strokeRoundedCheckList,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ClassModulesView(
                                classId: classId,
                              ),
                            ),
                          );
                        },
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
                Text(
                  'Error al cargar detalle',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: TextStyle(
                      fontSize: 14, color: AppColors.lightTextSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SacButton.primary(
                  text: 'Reintentar',
                  icon: HugeIcons.strokeRoundedRefresh,
                  onPressed: () {
                    ref.invalidate(classDetailProvider(classId));
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
