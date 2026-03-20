import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';

import '../../domain/entities/activity.dart';
import '../providers/activities_providers.dart';

/// Vista para editar una actividad existente.
///
/// Permite actualizar los campos que el endpoint PATCH /activities/:id soporta:
/// nombre, descripción y lugar.
class EditActivityView extends ConsumerStatefulWidget {
  /// Actividad a editar con sus datos actuales.
  final Activity activity;

  const EditActivityView({
    super.key,
    required this.activity,
  });

  @override
  ConsumerState<EditActivityView> createState() => _EditActivityViewState();
}

class _EditActivityViewState extends ConsumerState<EditActivityView> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.activity.name);
    _descriptionController =
        TextEditingController(text: widget.activity.description ?? '');
    _locationController =
        TextEditingController(text: widget.activity.activityPlace);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(updateActivityNotifierProvider.notifier);
    final success = await notifier.update(
      activityId: widget.activity.id,
      title: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      location: _locationController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Actividad actualizada correctamente'),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final updateState = ref.watch(updateActivityNotifierProvider);
    final c = context.sac;
    final isLoading = updateState.isLoading;

    // Mostrar error del notifier cuando cambia
    ref.listen<UpdateActivityState>(
      updateActivityNotifierProvider,
      (previous, next) {
        if (next.errorMessage != null &&
            next.errorMessage != previous?.errorMessage) {
          _showError(next.errorMessage!);
        }
      },
    );

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        foregroundColor: c.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: c.text,
            size: 22,
          ),
          onPressed: isLoading ? null : () => Navigator.pop(context),
          tooltip: 'Volver',
        ),
        title: Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedEdit02,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'EDITAR ACTIVIDAD',
                  style: TextStyle(
                    color: c.text,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0,
                  ),
                ),
                Text(
                  'Modifica los datos de la actividad',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: c.border),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Nombre ────────────────────────────────────────────────
            SacTextField(
              controller: _nameController,
              label: 'Nombre de la actividad *',
              hint: 'Ej: Campamento Distrital',
              prefixIcon: HugeIcons.strokeRoundedCalendar01,
              textCapitalization: TextCapitalization.sentences,
              enabled: !isLoading,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El nombre es requerido';
                }
                if (value.trim().length < 3) {
                  return 'El nombre debe tener al menos 3 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ── Descripción ───────────────────────────────────────────
            SacTextField(
              controller: _descriptionController,
              label: 'Descripción',
              hint: 'Describe brevemente la actividad...',
              prefixIcon: HugeIcons.strokeRoundedNote,
              maxLines: 3,
              enabled: !isLoading,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),

            // ── Lugar ─────────────────────────────────────────────────
            SacTextField(
              controller: _locationController,
              label: 'Lugar *',
              hint: 'Ej: Salón principal',
              prefixIcon: HugeIcons.strokeRoundedLocation01,
              textCapitalization: TextCapitalization.sentences,
              enabled: !isLoading,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El lugar es requerido';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            // ── Botón guardar ─────────────────────────────────────────
            SacButton.primary(
              text: 'Guardar cambios',
              icon: HugeIcons.strokeRoundedFloppyDisk,
              isLoading: isLoading,
              isEnabled: !isLoading,
              onPressed: _handleSave,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
