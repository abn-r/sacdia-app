import 'package:easy_localization/easy_localization.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_progress_ring.dart';
import 'package:sacdia_app/core/widgets/sac_back_button.dart';

import '../providers/classes_providers.dart';
import 'class_modules_view.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

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
    final classProgressAsync = ref.watch(
      classWithProgressProvider(ClassProgressQuery(classId: classId)),
    );
    final progressRatio = classProgressAsync.whenOrNull(
          data: (cwp) => cwp.completionRatio,
        ) ??
        0.0;
    final progressPercent = (progressRatio * 100).round();
    final onAccent = SacAccent.of(context).onColor;

    return Scaffold(
      backgroundColor: context.sac.background,
      body: classDetailAsync.when(
        data: (progressiveClass) {
          return CustomScrollView(
            slivers: [
              // Gradient header with progress ring
              SliverAppBar(
                automaticallyImplyLeading: false,
                leading: sacAutoBackButton(context),
                expandedHeight: 260,
                pinned: true,
                backgroundColor: SacAccent.of(context).color,
                foregroundColor: onAccent,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          SacAccent.of(context).color,
                          SacAccent.of(context).dark,
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
                            progress: progressRatio,
                            size: 120,
                            strokeWidth: 8,
                            color: onAccent,
                            trackColor: onAccent.withValues(alpha: 0.24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$progressPercent%',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: onAccent,
                                      ),
                                ),
                                Text(
                                  'classes.detail.progress_label'.tr(),
                                  style: TextStyle(
                                    fontSize: SacFontSize.bodySmall,
                                    color: onAccent.withValues(alpha: 0.7),
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
                                  color: onAccent,
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
                            HugeIcon(
                                icon: HugeIcons.strokeRoundedInformationCircle,
                                size: 20,
                                color: SacAccent.of(context).color),
                            const SizedBox(width: 8),
                            Text(
                              'classes.detail.description_header'.tr(),
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
                            fontSize: SacFontSize.titleSmall,
                            height: 1.6,
                            color: context.sac.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],

                      // Modules button
                      SacButton.primary(
                        text: 'classes.detail.view_modules_button'.tr(),
                        icon: HugeIcons.strokeRoundedCheckList,
                        onPressed: () {
                          Navigator.push(
                            context,
                            SacSharedAxisRoute(
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
        error: (error, stack) => SacErrorState(
          title: 'classes.detail.error_loading'.tr(),
          message: userErrorMessage(error),
          onRetry: () {
            ref.invalidate(classDetailProvider(classId));
          },
        ),
      ),
    );
  }
}
