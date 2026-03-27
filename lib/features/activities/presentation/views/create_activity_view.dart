import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';
import 'package:sacdia_app/features/post_registration/presentation/widgets/bottom_sheet_picker.dart';
import 'package:sacdia_app/providers/catalogs_provider.dart';
import '../../data/models/create_activity_request.dart';
import '../providers/activities_providers.dart';
import '../widgets/activity_form_widgets.dart';
import 'location_picker_view.dart';
import '../../../members/presentation/providers/members_providers.dart';

/// Vista para crear una nueva actividad en el club.
///
/// Expone todos los campos requeridos y opcionales del endpoint
/// POST /api/v1/clubs/:clubId/activities.
///
/// El picker de "Tipo de club" fue eliminado — el backend deriva `club_type_id`
/// desde la sección del usuario autenticado.
///
/// Solo los directores pueden crear actividades conjuntas (is_joint). Cuando
/// el toggle está activo, se muestra un picker de secciones usando FilterChip.
class CreateActivityView extends ConsumerStatefulWidget {
  /// ID del club al que pertenece la actividad.
  final int clubId;

  /// ID de la sección del club (club_sections) a la que pertenece la actividad.
  final int clubSectionId;

  const CreateActivityView({
    super.key,
    required this.clubId,
    required this.clubSectionId,
  });

  @override
  ConsumerState<CreateActivityView> createState() => _CreateActivityViewState();
}

class _CreateActivityViewState extends ConsumerState<CreateActivityView> {
  final _formKey = GlobalKey<FormState>();

  // Controladores de texto
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  // _imageController is kept for internal sync with the uploaded URL
  final _imageController = TextEditingController();
  final _timeController = TextEditingController(text: '09:00');
  final _linkMeetController = TextEditingController();

  // Ubicación seleccionada desde el mapa
  LocationPickerResult? _selectedLocation;
  // Flag para marcar que el usuario intentó guardar sin seleccionar ubicación
  bool _locationTouched = false;

  // Fechas de la actividad
  DateTime? _activityDate;
  DateTime? _activityEndDate;

  // Valores de picker / selector
  int _selectedPlatform = 0; // 0 = Presencial, 1 = Virtual
  int _selectedActivityType = 1; // 1 = Regular, 2 = Especial, 3 = Camporee
  String? _selectedActivityTypeName;

  // Image state: file picked locally (upload happens after activity creation)
  XFile? _pickedImageFile;
  bool _isUploadingImage = false;

  // Joint activity state
  bool _isJoint = false;
  Set<int> _selectedSectionIds = {};

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _imageController.dispose();
    _timeController.dispose();
    _linkMeetController.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _pickTime() async {
    final parts = _timeController.text.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.isNotEmpty ? parts[0] : '9') ?? 9,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );

    final picked = await showTimePickerSheet(context, initial);

    if (picked != null && mounted) {
      final hh = picked.hour.toString().padLeft(2, '0');
      final mm = picked.minute.toString().padLeft(2, '0');
      _timeController.text = '$hh:$mm';
    }
  }

  Future<void> _pickActivityDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _activityDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
      locale: const Locale('es'),
    );
    if (picked != null && mounted) {
      setState(() {
        _activityDate = picked;
        // Clear end date if it's before the new start date
        if (_activityEndDate != null &&
            _activityEndDate!.isBefore(picked)) {
          _activityEndDate = null;
        }
      });
    }
  }

  Future<void> _pickActivityEndDate() async {
    final now = DateTime.now();
    final minDate = _activityDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: _activityEndDate ?? minDate,
      firstDate: minDate,
      lastDate: DateTime(now.year + 5),
      locale: const Locale('es'),
    );
    if (picked != null && mounted) {
      setState(() => _activityEndDate = picked);
    }
  }

  Future<void> _openLocationPicker() async {
    final result = await Navigator.push<LocationPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerView(
          initialLocation: _selectedLocation != null
              ? LatLng(_selectedLocation!.lat, _selectedLocation!.long)
              : null,
        ),
        fullscreenDialog: true,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedLocation = result;
        _locationTouched = true;
      });
    }
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (picked == null || !mounted) return;

    setState(() => _pickedImageFile = picked);
  }

  Future<void> _handleSave() async {
    // Marcar ubicación como tocada para mostrar error si falta
    setState(() => _locationTouched = true);

    // Validar formulario
    if (!_formKey.currentState!.validate()) return;

    if (_selectedLocation == null) {
      _showError('Selecciona el lugar de la actividad en el mapa');
      return;
    }

    // Para actividades virtuales se requiere imagen
    if (_selectedPlatform == 1 && _pickedImageFile == null) {
      _showError('Selecciona una imagen para la actividad virtual');
      return;
    }

    // Validar secciones para actividades conjuntas
    if (_isJoint && _selectedSectionIds.length < 2) {
      _showError('Selecciona al menos 2 secciones para una actividad conjunta');
      return;
    }

    final clubSectionIds = _isJoint ? _selectedSectionIds.toList() : null;

    final request = CreateActivityRequest(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      lat: _selectedLocation!.lat,
      long: _selectedLocation!.long,
      activityTime: _timeController.text.trim().isEmpty
          ? '09:00'
          : _timeController.text.trim(),
      activityPlace: _selectedLocation!.name,
      image: null, // set after upload
      platform: _selectedPlatform,
      activityTypeId: _selectedActivityType,
      linkMeet: _linkMeetController.text.trim().isEmpty
          ? null
          : _linkMeetController.text.trim(),
      clubSectionId: widget.clubSectionId,
      activityDate: _activityDate,
      activityEndDate: _activityEndDate,
      clubSectionIds: clubSectionIds,
    );

    final notifier = ref.read(createActivityNotifierProvider.notifier);
    final success = await notifier.create(
      clubId: widget.clubId,
      request: request,
    );

    if (!mounted) return;
    if (!success) return; // error shown via notifier state

    final createdActivity = ref.read(createActivityNotifierProvider).createdActivity;

    // Upload image if one was picked
    if (_pickedImageFile != null && createdActivity != null) {
      setState(() => _isUploadingImage = true);

      final repository = ref.read(activitiesRepositoryProvider);
      final uploadResult = await repository.uploadActivityImage(
        createdActivity.id,
        File(_pickedImageFile!.path),
      );

      if (mounted) setState(() => _isUploadingImage = false);

      if (!mounted) return;

      uploadResult.fold(
        (failure) {
          // Activity was created — just warn about the image
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Actividad creada, pero hubo un error al subir la imagen: ${failure.message}',
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        },
        (_) {}, // success — no extra feedback needed
      );
    }

    if (!mounted) return;

    // Invalidar la lista de actividades para que se recargue
    ref.invalidate(clubActivitiesProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Actividad creada correctamente'),
        backgroundColor: AppColors.secondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );

    Navigator.of(context).pop(true);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final createState = ref.watch(createActivityNotifierProvider);
    final activityTypesAsync = ref.watch(activityTypesProvider);
    final clubCtxAsync = ref.watch(clubContextProvider);
    final c = context.sac;
    final isLoading = createState.isLoading || _isUploadingImage;
    final activityTypeItems = activityTypesAsync.maybeWhen(
      data: (activityTypes) => activityTypes
          .map((t) => PickerItem(id: t.activityTypeId, name: t.name))
          .toList(),
      orElse: () => const <PickerItem>[],
    );

    // Only directors can create joint activities
    final isDirector = clubCtxAsync.valueOrNull?.isDirector ?? false;

    // Mostrar error del notifier si hay uno nuevo
    ref.listen<CreateActivityState>(
      createActivityNotifierProvider,
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
              icon: HugeIcons.strokeRoundedCalendarAdd01,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'NUEVA ACTIVIDAD',
                  style: TextStyle(
                    color: c.text,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0,
                  ),
                ),
                Text(
                  'Completa los datos de la actividad',
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
            // ── Sección: Información general ──────────────────────────
            ActivitySectionHeader(
              icon: HugeIcons.strokeRoundedInformationCircle,
              label: 'Información general',
            ),
            const SizedBox(height: 12),

            // Nombre *
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

            // Descripción (opcional)
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

            // Tipo de actividad
            ActivityPickerField(
              label: 'Tipo de actividad',
              hint: activityTypesAsync.isLoading
                  ? 'Cargando tipos...'
                  : 'Seleccionar tipo de actividad',
              icon: Icons.label_rounded,
              selectedName: _selectedActivityTypeName,
              enabled: !isLoading &&
                  !activityTypesAsync.isLoading &&
                  activityTypeItems.isNotEmpty,
              isLoading: activityTypesAsync.isLoading,
              onTap: () async {
                if (activityTypeItems.isEmpty) return;
                final selected = await showPickerSheet(
                  context: context,
                  title: 'Tipo de actividad',
                  items: activityTypeItems,
                  selectedId: _selectedActivityType,
                  icon: Icons.label_rounded,
                );
                if (selected != null && mounted) {
                  setState(() {
                    _selectedActivityType = selected;
                    _selectedActivityTypeName = activityTypeItems
                        .firstWhere((i) => i.id == selected)
                        .name;
                  });
                }
              },
            ),
            const SizedBox(height: 24),

            // ── Sección: Actividad conjunta (solo directores) ─────────
            if (isDirector) ...[
              ActivitySectionHeader(
                icon: HugeIcons.strokeRoundedUserGroup,
                label: 'Actividad conjunta',
              ),
              const SizedBox(height: 8),
              _JointActivityToggle(
                value: _isJoint,
                enabled: !isLoading,
                onChanged: (val) {
                  setState(() {
                    _isJoint = val;
                    if (!val) {
                      // Reset selection when disabling joint mode
                      _selectedSectionIds = {};
                    } else {
                      // Pre-select own section
                      _selectedSectionIds = {widget.clubSectionId};
                    }
                  });
                },
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: _isJoint
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          _SectionMultiPicker(
                            clubId: widget.clubId,
                            ownSectionId: widget.clubSectionId,
                            selectedIds: _selectedSectionIds,
                            enabled: !isLoading,
                            onChanged: (ids) =>
                                setState(() => _selectedSectionIds = ids),
                          ),
                          const SizedBox(height: 8),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
            ],

            // ── Sección: Lugar y tiempo ───────────────────────────────
            ActivitySectionHeader(
              icon: HugeIcons.strokeRoundedLocation01,
              label: 'Lugar y tiempo',
            ),
            const SizedBox(height: 12),

            // Selector de ubicación (tappable — abre el mapa) *
            ActivityLocationPickerField(
              result: _selectedLocation,
              hasError: _locationTouched && _selectedLocation == null,
              enabled: !isLoading,
              onTap: isLoading ? null : _openLocationPicker,
            ),
            const SizedBox(height: 16),

            // Fecha de inicio
            ActivityDatePickerField(
              label: 'Fecha',
              value: _activityDate,
              enabled: !isLoading,
              onTap: isLoading ? null : _pickActivityDate,
              onClear: _activityDate == null
                  ? null
                  : () => setState(() {
                        _activityDate = null;
                        _activityEndDate = null;
                      }),
            ),
            const SizedBox(height: 16),

            // Hora
            SacTextField(
              controller: _timeController,
              label: 'Hora',
              hint: '09:00',
              prefixIcon: HugeIcons.strokeRoundedClock01,
              readOnly: true,
              enabled: !isLoading,
              onTap: isLoading ? null : _pickTime,
              suffix: IconButton(
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedClock01,
                  size: 18,
                  color: AppColors.primary,
                ),
                onPressed: isLoading ? null : _pickTime,
              ),
            ),
            const SizedBox(height: 16),

            // Fecha de fin (opcional)
            ActivityDatePickerField(
              label: 'Fecha de fin (opcional)',
              value: _activityEndDate,
              enabled: !isLoading && _activityDate != null,
              onTap:
                  (isLoading || _activityDate == null) ? null : _pickActivityEndDate,
              onClear: _activityEndDate == null
                  ? null
                  : () => setState(() => _activityEndDate = null),
            ),
            const SizedBox(height: 24),

            // ── Sección: Modalidad ────────────────────────────────────
            ActivitySectionHeader(
              icon: HugeIcons.strokeRoundedComputerVideoCall,
              label: 'Modalidad',
            ),
            const SizedBox(height: 12),

            // Plataforma (presencial / virtual) — always visible
            ActivitySegmentedSelector<int>(
              label: 'Tipo de actividad',
              value: _selectedPlatform,
              options: const [
                ActivitySegmentOption(value: 0, label: 'Presencial'),
                ActivitySegmentOption(value: 1, label: 'Virtual'),
              ],
              onChanged: isLoading
                  ? null
                  : (v) => setState(() {
                        _selectedPlatform = v;
                        // Reset image when switching to presencial
                        if (v == 0) {
                          _pickedImageFile = null;
                          _imageController.clear();
                        }
                      }),
            ),
            const SizedBox(height: 16),

            // Virtual-only fields (animated in/out)
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: _selectedPlatform == 1
                  ? Column(
                      children: [
                        // Link videoconferencia
                        SacTextField(
                          controller: _linkMeetController,
                          label: 'Link de videoconferencia',
                          hint: 'https://meet.google.com/...',
                          prefixIcon: HugeIcons.strokeRoundedComputerVideoCall,
                          keyboardType: TextInputType.url,
                          enabled: !isLoading,
                        ),
                        const SizedBox(height: 16),
                        // Image picker
                        ActivityImagePicker(
                          localImagePath: _pickedImageFile?.path,
                          isUploading: _isUploadingImage,
                          enabled: !isLoading,
                          onPickGallery: () =>
                              _pickAndUploadImage(ImageSource.gallery),
                          onPickCamera: () =>
                              _pickAndUploadImage(ImageSource.camera),
                        ),
                        const SizedBox(height: 16),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 8),

            // ── Botón de guardar ──────────────────────────────────────
            SacButton.primary(
              text: 'Crear Actividad',
              icon: HugeIcons.strokeRoundedCalendarAdd01,
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

// ─────────────────────────────────────────────────────────────────────────────
// Toggle de actividad conjunta
// ─────────────────────────────────────────────────────────────────────────────

class _JointActivityToggle extends StatelessWidget {
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _JointActivityToggle({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value
              ? AppColors.primary.withValues(alpha: 0.4)
              : c.border,
          width: value ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: c.shadow,
            offset: const Offset(0, 3),
            blurRadius: 12,
          ),
        ],
      ),
      child: SwitchListTile(
        value: value,
        onChanged: enabled ? onChanged : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          'Actividad conjunta',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: c.text,
          ),
        ),
        subtitle: Text(
          'Incluye otras secciones del club',
          style: TextStyle(
            fontSize: 12,
            color: c.textSecondary,
          ),
        ),
        secondary: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: value ? AppColors.primaryLight : c.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedUserGroup,
            size: 18,
            color: value ? AppColors.primary : c.textTertiary,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Picker de secciones para actividades conjuntas
// ─────────────────────────────────────────────────────────────────────────────

class _SectionMultiPicker extends ConsumerWidget {
  final int clubId;
  final int ownSectionId;
  final Set<int> selectedIds;
  final bool enabled;
  final ValueChanged<Set<int>> onChanged;

  const _SectionMultiPicker({
    required this.clubId,
    required this.ownSectionId,
    required this.selectedIds,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sectionsAsync = ref.watch(clubSectionsForActivityProvider);
    final c = context.sac;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Secciones participantes',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Selecciona al menos 2 secciones. Tu sección siempre participa.',
          style: TextStyle(
            fontSize: 12,
            color: c.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        sectionsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (_, __) => Text(
            'No se pudieron cargar las secciones',
            style: TextStyle(
              fontSize: 12,
              color: c.textSecondary,
            ),
          ),
          data: (sections) {
            if (sections.isEmpty) {
              return Text(
                'No hay secciones disponibles',
                style: TextStyle(fontSize: 12, color: c.textSecondary),
              );
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sections.map((section) {
                final isOwn = section.clubSectionId == ownSectionId;
                final isSelected =
                    selectedIds.contains(section.clubSectionId) || isOwn;
                final label =
                    section.clubTypeName ?? 'Sección ${section.clubSectionId}';

                return FilterChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: enabled && !isOwn
                      ? (selected) {
                          final updated = Set<int>.from(selectedIds);
                          // Own section is always included
                          updated.add(ownSectionId);
                          if (selected) {
                            updated.add(section.clubSectionId);
                          } else {
                            updated.remove(section.clubSectionId);
                          }
                          onChanged(updated);
                        }
                      : null,
                  selectedColor: AppColors.primaryLight,
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? AppColors.primaryDark
                        : c.textSecondary,
                  ),
                  backgroundColor: c.surface,
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : c.border,
                  ),
                  avatar: isOwn
                      ? Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: AppColors.primary,
                        )
                      : null,
                );
              }).toList(),
            );
          },
        ),
        if (selectedIds.length < 2) ...[
          const SizedBox(height: 6),
          Text(
            'Selecciona al menos 1 sección adicional',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.error,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
