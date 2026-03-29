import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';
import 'package:sacdia_app/features/post_registration/presentation/widgets/bottom_sheet_picker.dart';
import 'package:sacdia_app/providers/catalogs_provider.dart';

import '../../domain/entities/activity.dart';
import '../providers/activities_providers.dart';
import '../widgets/activity_form_widgets.dart';
import 'location_picker_view.dart';
import '../../../members/presentation/providers/members_providers.dart';

/// Vista para editar una actividad existente.
///
/// Pre-popula todos los campos desde [activity] y permite actualizar
/// todos los campos que el endpoint PATCH /activities/:id soporta.
///
/// Para directores, expone el toggle de "Actividad conjunta" con el picker
/// de secciones participantes. Para no-directores que editan una actividad
/// conjunta, muestra un chip informativo de solo lectura.
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

  // ── Controladores de texto ─────────────────────────────────────────────────
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _timeController;
  late final TextEditingController _linkMeetController;

  // ── Ubicación ──────────────────────────────────────────────────────────────
  LocationPickerResult? _selectedLocation;
  bool _locationTouched = false;

  // ── Fechas ─────────────────────────────────────────────────────────────────
  DateTime? _activityDate;
  DateTime? _activityEndDate;

  // ── Tipo de actividad ─────────────────────────────────────────────────────
  late int _selectedActivityType;
  String? _selectedActivityTypeName;

  // ── Plataforma (0=Presencial, 1=Virtual) ──────────────────────────────────
  late int _selectedPlatform;

  // ── Imagen ────────────────────────────────────────────────────────────────
  XFile? _pickedImageFile;
  bool _isUploadingImage = false;

  // ── Actividad conjunta ─────────────────────────────────────────────────────
  bool _isJoint = false;
  Set<int> _selectedSectionIds = {};

  @override
  void initState() {
    super.initState();

    final a = widget.activity;

    _nameController = TextEditingController(text: a.name);
    _descriptionController = TextEditingController(text: a.description ?? '');
    _timeController = TextEditingController(text: a.activityTime ?? '09:00');
    _linkMeetController = TextEditingController(text: a.linkMeet ?? '');

    // Pre-populate location from existing coordinates + place name
    if (a.lat != null && a.longitude != null) {
      _selectedLocation = LocationPickerResult(
        name: a.activityPlace,
        lat: a.lat!,
        long: a.longitude!,
      );
    }

    _activityDate = a.activityDate;
    _activityEndDate = a.activityEndDate;
    _selectedPlatform = a.platform;
    _selectedActivityType = a.activityType;

    // Pre-populate joint activity state from the existing activity
    _isJoint = a.isJoint;
    if (a.isJoint && a.instances != null) {
      _selectedSectionIds =
          a.instances!.map((i) => i.clubSectionId).toSet();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _timeController.dispose();
    _linkMeetController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

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
        if (_activityEndDate != null && _activityEndDate!.isBefore(picked)) {
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

  Future<void> _pickImage(ImageSource source) async {
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
    setState(() => _locationTouched = true);

    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    if (_selectedLocation == null) {
      _showError('Selecciona el lugar de la actividad en el mapa');
      return;
    }

    // Validate joint activity sections when the user is a director
    final clubCtx = ref.read(clubContextProvider).valueOrNull;
    final isDirector = clubCtx?.isDirector ?? false;
    if (isDirector && _isJoint && _selectedSectionIds.length < 2) {
      _showError('Selecciona al menos 2 secciones para una actividad conjunta');
      return;
    }

    final a = widget.activity;
    final clearFields = <String>{};

    // Detect which nullable fields were explicitly cleared
    final descText = _descriptionController.text.trim();
    final String? newDescription = descText.isEmpty ? null : descText;
    if (a.description != null && newDescription == null) {
      clearFields.add('description');
    }

    if (a.activityDate != null && _activityDate == null) {
      clearFields.add('activity_date');
    }
    if (a.activityEndDate != null && _activityEndDate == null) {
      clearFields.add('activity_end_date');
    }

    final linkText = _linkMeetController.text.trim();
    final String? newLinkMeet = linkText.isEmpty ? null : linkText;
    if (a.linkMeet != null && newLinkMeet == null) {
      clearFields.add('link_meet');
    }

    // Resolve club_section_ids only when the director actively controls joint mode
    List<int>? clubSectionIds;
    if (isDirector) {
      clubSectionIds = _isJoint ? _selectedSectionIds.toList() : null;
    }

    final notifier = ref.read(updateActivityNotifierProvider.notifier);
    final success = await notifier.update(
      activityId: a.id,
      name: _nameController.text.trim(),
      description: newDescription,
      lat: _selectedLocation!.lat,
      long: _selectedLocation!.long,
      activityPlace: _selectedLocation!.name,
      activityTime: _timeController.text.trim().isEmpty
          ? '09:00'
          : _timeController.text.trim(),
      activityDate: _activityDate?.toUtc().toIso8601String(),
      activityEndDate: _activityEndDate?.toUtc().toIso8601String(),
      platform: _selectedPlatform,
      activityTypeId: _selectedActivityType,
      linkMeet: newLinkMeet,
      clearFields: clearFields,
      clubSectionIds: clubSectionIds,
    );

    if (!mounted) return;
    if (!success) return;

    // Upload new image if one was picked
    if (_pickedImageFile != null) {
      setState(() => _isUploadingImage = true);

      final repository = ref.read(activitiesRepositoryProvider);
      final uploadResult = await repository.uploadActivityImage(
        a.id,
        File(_pickedImageFile!.path),
      );

      if (mounted) setState(() => _isUploadingImage = false);
      if (!mounted) return;

      uploadResult.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Actividad actualizada, pero hubo un error al subir la imagen: ${failure.message}',
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        },
        (_) {},
      );
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Actividad actualizada correctamente'),
        backgroundColor: AppColors.secondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    Navigator.of(context).pop(true);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final updateState = ref.watch(updateActivityNotifierProvider);
    final activityTypesAsync = ref.watch(activityTypesProvider);
    final clubCtxAsync = ref.watch(clubContextProvider);
    final c = context.sac;
    final isLoading = updateState.isLoading || _isUploadingImage;

    final activityTypeItems = activityTypesAsync.maybeWhen(
      data: (activityTypes) => activityTypes
          .map((t) => PickerItem(id: t.activityTypeId, name: t.name))
          .toList(),
      orElse: () => const <PickerItem>[],
    );

    // Only directors can edit joint activity settings
    final isDirector = clubCtxAsync.valueOrNull?.isDirector ?? false;
    final ownSectionId = clubCtxAsync.valueOrNull?.sectionId;

    // Sync activity type name once types are loaded
    if (_selectedActivityTypeName == null && activityTypeItems.isNotEmpty) {
      try {
        _selectedActivityTypeName = activityTypeItems
            .firstWhere((i) => i.id == _selectedActivityType)
            .name;
      } catch (_) {
        // activityType not found in catalog — keep null
      }
    }

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
              icon: HugeIcons.strokeRoundedLabel,
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

            // ── Sección: Actividad conjunta ────────────────────────────
            // Directors: editable toggle + section picker
            // Non-directors on a joint activity: read-only info chip
            if (isDirector && ownSectionId != null) ...[
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
                      _selectedSectionIds = {};
                    } else {
                      // Keep existing selections if re-enabling, or seed with own section
                      if (_selectedSectionIds.isEmpty) {
                        _selectedSectionIds = {ownSectionId};
                      } else {
                        // Always ensure own section is present
                        _selectedSectionIds = {
                          ownSectionId,
                          ..._selectedSectionIds,
                        };
                      }
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
                            ownSectionId: ownSectionId,
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
            ] else if (!isDirector && widget.activity.isJoint) ...[
              // Read-only info chip for non-directors viewing a joint activity
              _JointActivityReadOnlyBadge(activity: widget.activity),
              const SizedBox(height: 24),
            ],

            // ── Sección: Lugar y tiempo ───────────────────────────────
            ActivitySectionHeader(
              icon: HugeIcons.strokeRoundedLocation01,
              label: 'Lugar y tiempo',
            ),
            const SizedBox(height: 12),

            // Selector de ubicación (abre el mapa) *
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
              onTap: (isLoading || _activityDate == null)
                  ? null
                  : _pickActivityEndDate,
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

            // Plataforma (presencial / virtual)
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
                        if (v == 0) _pickedImageFile = null;
                      }),
            ),
            const SizedBox(height: 16),

            // Campos solo para virtual
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: _selectedPlatform == 1
                  ? Column(
                      children: [
                        SacTextField(
                          controller: _linkMeetController,
                          label: 'Link de videoconferencia',
                          hint: 'https://meet.google.com/...',
                          prefixIcon: HugeIcons.strokeRoundedComputerVideoCall,
                          keyboardType: TextInputType.url,
                          enabled: !isLoading,
                        ),
                        const SizedBox(height: 16),
                        ActivityImagePicker(
                          localImagePath: _pickedImageFile?.path,
                          networkImageUrl: _pickedImageFile == null
                              ? widget.activity.image
                              : null,
                          isUploading: _isUploadingImage,
                          enabled: !isLoading,
                          onPickGallery: () => _pickImage(ImageSource.gallery),
                          onPickCamera: () => _pickImage(ImageSource.camera),
                        ),
                        const SizedBox(height: 16),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 8),

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

// ─────────────────────────────────────────────────────────────────────────────
// Toggle de actividad conjunta (editable — solo directores)
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
// Picker de secciones para actividades conjuntas (editable — solo directores)
// ─────────────────────────────────────────────────────────────────────────────

class _SectionMultiPicker extends ConsumerWidget {
  final int ownSectionId;
  final Set<int> selectedIds;
  final bool enabled;
  final ValueChanged<Set<int>> onChanged;

  const _SectionMultiPicker({
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

// ─────────────────────────────────────────────────────────────────────────────
// Badge de solo lectura para actividades conjuntas (no directores)
// ─────────────────────────────────────────────────────────────────────────────

class _JointActivityReadOnlyBadge extends StatelessWidget {
  final Activity activity;

  const _JointActivityReadOnlyBadge({required this.activity});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final theme = Theme.of(context);

    // Collect participating section names from instances
    final sectionNames = activity.instances
            ?.map((i) => i.clubTypeName ?? 'Sección ${i.clubSectionId}')
            .toList() ??
        const <String>[];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedUserGroup,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Actividad conjunta',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
                if (sectionNames.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: sectionNames
                        .map(
                          (name) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: c.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color:
                                    AppColors.primary.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ] else ...[
                  const SizedBox(height: 4),
                  Text(
                    'Esta actividad incluye múltiples secciones',
                    style: TextStyle(
                      fontSize: 12,
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Campo de solo lectura para mostrar información no editable
// ─────────────────────────────────────────────────────────────────────────────

class _ReadOnlyInfoField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ReadOnlyInfoField({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: c.surfaceVariant,
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            border: Border.all(color: c.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Icon(icon, size: 20, color: c.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: c.textSecondary,
                  ),
                ),
              ),
              Icon(Icons.lock_outline_rounded, size: 16, color: c.textTertiary),
            ],
          ),
        ),
      ],
    );
  }
}
