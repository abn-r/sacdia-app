import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_card.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/class_section.dart';
import '../providers/classes_providers.dart';

/// Vista de detalle de una sección de clase
class SectionDetailView extends ConsumerStatefulWidget {
  final ClassSection section;
  final int classId;

  const SectionDetailView({
    Key? key,
    required this.section,
    required this.classId,
  }) : super(key: key);

  @override
  ConsumerState<SectionDetailView> createState() => _SectionDetailViewState();
}

class _SectionDetailViewState extends ConsumerState<SectionDetailView> {
  late bool _isCompleted;

  @override
  void initState() {
    super.initState();
    _isCompleted = widget.section.isCompleted;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Sección'),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título de la sección
            Text(
              widget.section.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            // Estado de completitud
            SacCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    HugeIcon(
                      icon: _isCompleted ? HugeIcons.strokeRoundedCheckmarkCircle02 : HugeIcons.strokeRoundedRadioButton,
                      color: _isCompleted ? AppColors.success : context.sac.textSecondary,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isCompleted ? 'Completada' : 'Pendiente',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _isCompleted
                                      ? AppColors.success
                                      : context.sac.textSecondary,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isCompleted
                                ? 'Has completado esta sección'
                                : 'Marca esta sección como completada',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Botón para marcar como completado/pendiente
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final userId = authState.value?.id;
                  if (userId == null) return;

                  final newStatus = !_isCompleted;

                  // Actualizar progreso
                  await ref.read(classProgressNotifierProvider.notifier).updateProgress(
                        userId,
                        widget.classId,
                        {
                          'section_id': widget.section.id,
                          'is_completed': newStatus,
                        },
                      );

                  if (!mounted) return;

                  setState(() {
                    _isCompleted = newStatus;
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        newStatus
                            ? 'Sección marcada como completada'
                            : 'Sección marcada como pendiente',
                      ),
                      backgroundColor: newStatus ? AppColors.success : AppColors.warning,
                    ),
                  );
                },
                icon: HugeIcon(icon: _isCompleted ? HugeIcons.strokeRoundedCancel01 : HugeIcons.strokeRoundedTick02, color: Colors.white, size: 24),
                label: Text(_isCompleted ? 'Marcar como pendiente' : 'Marcar como completada'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isCompleted ? AppColors.warning : AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
