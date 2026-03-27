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

/// Vista para crear una nueva actividad en el club.
///
/// Expone todos los campos requeridos y opcionales del endpoint
/// POST /api/v1/clubs/:clubId/activities.
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
  int? _selectedClubTypeId;
  String? _selectedClubTypeName;
  int _selectedPlatform = 0; // 0 = Presencial, 1 = Virtual
  int _selectedActivityType = 1; // 1 = Regular, 2 = Especial, 3 = Camporee
  String? _selectedActivityTypeName;

  // Image state: file picked locally (upload happens after activity creation)
  XFile? _pickedImageFile;
  bool _isUploadingImage = false;

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

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );

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

    if (_selectedClubTypeId == null) {
      _showError('Selecciona el tipo de club');
      return;
    }

    if (_selectedLocation == null) {
      _showError('Selecciona el lugar de la actividad en el mapa');
      return;
    }

    // Para actividades virtuales se requiere imagen
    if (_selectedPlatform == 1 && _pickedImageFile == null) {
      _showError('Selecciona una imagen para la actividad virtual');
      return;
    }

    final request = CreateActivityRequest(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      clubTypeId: _selectedClubTypeId!,
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
    final c = context.sac;
    final isLoading = createState.isLoading || _isUploadingImage;
    final activityTypeItems = activityTypesAsync.maybeWhen(
      data: (activityTypes) => activityTypes
          .map((t) => PickerItem(id: t.activityTypeId, name: t.name))
          .toList(),
      orElse: () => const <PickerItem>[],
    );

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

            // Tipo de club *
            ActivityPickerField(
              label: 'Tipo de club *',
              hint: 'Seleccionar tipo de club',
              icon: Icons.group_rounded,
              selectedName: _selectedClubTypeName,
              enabled: !isLoading,
              onTap: () async {
                const clubItems = [
                  PickerItem(id: 1, name: 'Aventureros'),
                  PickerItem(id: 2, name: 'Conquistadores'),
                  PickerItem(id: 3, name: 'Guias Mayores'),
                ];
                final selected = await showPickerSheet(
                  context: context,
                  title: 'Tipo de club',
                  items: clubItems,
                  selectedId: _selectedClubTypeId,
                  icon: Icons.group_rounded,
                );
                if (selected != null && mounted) {
                  setState(() {
                    _selectedClubTypeId = selected;
                    _selectedClubTypeName = clubItems
                        .firstWhere((i) => i.id == selected)
                        .name;
                  });
                }
              },
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
