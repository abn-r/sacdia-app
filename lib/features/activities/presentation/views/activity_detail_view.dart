import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/activity.dart';
import '../providers/activities_providers.dart';
import '../widgets/attendance_button.dart';
import '../widgets/activity_info_row.dart';
import 'edit_activity_view.dart';

/// Vista de detalle de actividad - Estilo "Scout Vibrante"
///
/// Header con gradiente por tipo, info rows con iconBox,
/// AttendanceButton, floating SnackBars.
class ActivityDetailView extends ConsumerStatefulWidget {
  final int activityId;

  const ActivityDetailView({
    super.key,
    required this.activityId,
  });

  @override
  ConsumerState<ActivityDetailView> createState() => _ActivityDetailViewState();
}

class _ActivityDetailViewState extends ConsumerState<ActivityDetailView> {
  bool _hasRegistered = false;

  Color _getTypeColor(int type) {
    switch (type) {
      case 1:
        return AppColors.primary;
      case 2:
        return AppColors.accent;
      case 3:
        return AppColors.secondary;
      default:
        return AppColors.primary;
    }
  }

  dynamic _getTypeIcon(int type) {
    switch (type) {
      case 1:
        return HugeIcons.strokeRoundedUserGroup;
      case 2:
        return HugeIcons.strokeRoundedCalendar01;
      case 3:
        return HugeIcons.strokeRoundedCampfire;
      default:
        return HugeIcons.strokeRoundedCalendarAdd01;
    }
  }

  String _getTypeText(int type, [String? typeName]) {
    final normalizedName = typeName?.trim();
    if (normalizedName != null && normalizedName.isNotEmpty) {
      return normalizedName;
    }

    switch (type) {
      case 1:
        return 'Regular';
      case 2:
        return 'Especial';
      case 3:
        return 'Camporee';
      default:
        return 'Actividad';
    }
  }

  Future<void> _navigateToEdit(Activity activity) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditActivityView(activity: activity),
      ),
    );

    if (result == true && mounted) {
      ref.invalidate(activityDetailProvider(widget.activityId));
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar actividad'),
        content: const Text(
          '¿Estás seguro que querés eliminar esta actividad? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final success = await ref
        .read(deleteActivityNotifierProvider.notifier)
        .delete(widget.activityId);

    if (!mounted) return;

    if (success) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Actividad eliminada correctamente'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      navigator.pop();
    } else {
      final deleteState = ref.read(deleteActivityNotifierProvider);
      final errorMsg = deleteState.hasError
          ? deleteState.error?.toString() ?? 'Error al eliminar'
          : 'Error al eliminar';
      messenger.showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activityAsync = ref.watch(activityDetailProvider(widget.activityId));
    final authState = ref.watch(authNotifierProvider);
    final attendanceState = ref.watch(attendanceNotifierProvider);
    final deleteState = ref.watch(deleteActivityNotifierProvider);

    return Scaffold(
      backgroundColor: context.sac.background,
      body: activityAsync.when(
        data: (activity) {
          final typeColor = _getTypeColor(activity.activityType);

          return CustomScrollView(
            slivers: [
              // Header
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: typeColor,
                foregroundColor: Colors.white,
                actions: [
                  IconButton(
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedEdit02,
                      size: 22,
                      color: Colors.white,
                    ),
                    tooltip: 'Editar actividad',
                    onPressed: deleteState.isLoading
                        ? null
                        : () => _navigateToEdit(activity),
                  ),
                  IconButton(
                    icon: deleteState.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const HugeIcon(
                            icon: HugeIcons.strokeRoundedDelete02,
                            size: 22,
                            color: Colors.white,
                          ),
                    tooltip: 'Eliminar actividad',
                    onPressed: deleteState.isLoading
                        ? null
                        : _confirmDelete,
                  ),
                  const SizedBox(width: 4),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          typeColor,
                          typeColor.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          HugeIcon(
                            icon: _getTypeIcon(activity.activityType),
                            size: 48,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              activity.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _getTypeText(
                                activity.activityType,
                                activity.activityTypeName,
                              ),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
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
                      if (activity.createdAt != null)
                        ActivityInfoRow(
                          icon: HugeIcons.strokeRoundedCalendar01,
                          label: 'Fecha',
                          value: DateFormat('EEEE, dd MMMM yyyy', 'es')
                              .format(activity.createdAt!),
                        ),
                      if (activity.activityTime != null)
                        ActivityInfoRow(
                          icon: HugeIcons.strokeRoundedClock01,
                          label: 'Hora',
                          value: activity.activityTime!,
                        ),
                      ActivityInfoRow(
                        icon: HugeIcons.strokeRoundedLocation01,
                        label: 'Lugar',
                        value: activity.activityPlace,
                      ),
                      if (activity.linkMeet != null)
                        ActivityInfoRow(
                          icon: HugeIcons.strokeRoundedLink01,
                          label: 'Link',
                          value: activity.linkMeet!,
                        ),
                      if (activity.description != null) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            HugeIcon(
                                icon: HugeIcons.strokeRoundedInformationCircle,
                                size: 20,
                                color: AppColors.primary),
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
                          activity.description!,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: context.sac.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),

                      // Attendance button
                      AttendanceButton(
                        isAttending: _hasRegistered ||
                            (attendanceState.value != null &&
                                attendanceState.value! > 0),
                        isLoading: attendanceState.isLoading,
                        onPressed: () async {
                          final userId = authState.value?.id;
                          if (userId == null) return;

                          final messenger = ScaffoldMessenger.of(context);

                          await ref
                              .read(attendanceNotifierProvider.notifier)
                              .register(widget.activityId, userId);

                          if (!mounted) return;
                          final result = ref.read(attendanceNotifierProvider);
                          if (result.hasError) return;

                          setState(() {
                            _hasRegistered = true;
                          });

                          messenger.showSnackBar(
                            SnackBar(
                              content: const Text(
                                  'Asistencia registrada exitosamente'),
                              backgroundColor: AppColors.secondary,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
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
                HugeIcon(
                    icon: HugeIcons.strokeRoundedAlert02,
                    size: 56,
                    color: AppColors.error),
                const SizedBox(height: 16),
                Text('Error al cargar detalle',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 24),
                SacButton.primary(
                  text: 'Reintentar',
                  icon: HugeIcons.strokeRoundedRefresh,
                  onPressed: () {
                    ref.invalidate(activityDetailProvider(widget.activityId));
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
