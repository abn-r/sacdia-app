import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_dropdown_field.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';
import 'package:sacdia_app/providers/catalogs_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/create_activity_request.dart';
import '../providers/activities_providers.dart';
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

  // Valores de dropdown / selector
  int? _selectedClubTypeId;
  int _selectedPlatform = 0; // 0 = Presencial, 1 = Virtual
  int _selectedActivityType = 1; // 1 = Regular, 2 = Especial, 3 = Camporee

  // Image upload state
  String? _uploadedImageUrl;
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
    // 1. Pick image
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (picked == null || !mounted) return;

    // 2. Set loading state
    setState(() => _isUploadingImage = true);

    try {
      // 3. Upload to Supabase Storage
      final supabase = Supabase.instance.client;
      final bytes = await File(picked.path).readAsBytes();
      final ext = picked.path.split('.').last.toLowerCase();
      final fileName = 'activity_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = 'activities/$fileName';

      await supabase.storage
          .from('activities-images')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$ext'),
          );

      final url =
          supabase.storage.from('activities-images').getPublicUrl(path);

      if (mounted) {
        setState(() {
          _uploadedImageUrl = url;
          _imageController.text = url;
          _isUploadingImage = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error al subir la imagen. Intenta nuevamente.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
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
    if (_selectedPlatform == 1 && _uploadedImageUrl == null) {
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
      image: _uploadedImageUrl,
      platform: _selectedPlatform,
      activityTypeId: _selectedActivityType,
      linkMeet: _linkMeetController.text.trim().isEmpty
          ? null
          : _linkMeetController.text.trim(),
      clubSectionId: widget.clubSectionId,
    );

    final notifier = ref.read(createActivityNotifierProvider.notifier);
    final success = await notifier.create(
      clubId: widget.clubId,
      request: request,
    );

    if (!mounted) return;

    if (success) {
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
    // El error se muestra via el estado del notifier (ver build)
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
    final isLoading = createState.isLoading;
    final activityTypeItems = activityTypesAsync.maybeWhen(
      data: (activityTypes) => activityTypes
          .map(
            (activityType) => DropdownMenuItem<int>(
              value: activityType.activityTypeId,
              child: Text(activityType.name),
            ),
          )
          .toList(),
      orElse: () => const <DropdownMenuItem<int>>[],
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
            _SectionHeader(
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
            SacDropdownField<int>(
              value: _selectedClubTypeId,
              label: 'Tipo de club *',
              hint: 'Selecciona el tipo de club',
              prefixIcon: HugeIcons.strokeRoundedUserGroup,
              enabled: !isLoading,
              items: const [
                DropdownMenuItem(value: 1, child: Text('Aventureros')),
                DropdownMenuItem(value: 2, child: Text('Conquistadores')),
                DropdownMenuItem(value: 3, child: Text('Guias Mayores')),
              ],
              onChanged: (value) {
                setState(() => _selectedClubTypeId = value);
              },
              validator: (value) {
                if (value == null) return 'Selecciona el tipo de club';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Tipo de actividad
            SacDropdownField<int>(
              value: _selectedActivityType,
              label: 'Tipo de actividad',
              hint: activityTypesAsync.isLoading
                  ? 'Cargando tipos de actividad...'
                  : 'Selecciona el tipo',
              prefixIcon: HugeIcons.strokeRoundedTag01,
              helperText: activityTypesAsync.hasError
                  ? 'No se pudieron cargar los tipos. Intenta nuevamente.'
                  : null,
              enabled: !isLoading &&
                  !activityTypesAsync.isLoading &&
                  activityTypeItems.isNotEmpty,
              items: activityTypeItems,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedActivityType = value);
                }
              },
              validator: (value) {
                if (value == null) return 'Selecciona el tipo de actividad';
                return null;
              },
            ),
            const SizedBox(height: 24),

            // ── Sección: Lugar y tiempo ───────────────────────────────
            _SectionHeader(
              icon: HugeIcons.strokeRoundedLocation01,
              label: 'Lugar y tiempo',
            ),
            const SizedBox(height: 12),

            // Selector de ubicación (tappable — abre el mapa) *
            _LocationPickerField(
              result: _selectedLocation,
              hasError: _locationTouched && _selectedLocation == null,
              enabled: !isLoading,
              onTap: isLoading ? null : _openLocationPicker,
            ),
            const SizedBox(height: 16),

            // Hora
            SacTextField(
              controller: _timeController,
              label: 'Hora de inicio',
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
            const SizedBox(height: 24),

            // ── Sección: Modalidad ────────────────────────────────────
            _SectionHeader(
              icon: HugeIcons.strokeRoundedComputerVideoCall,
              label: 'Modalidad',
            ),
            const SizedBox(height: 12),

            // Plataforma (presencial / virtual) — always visible
            _SegmentedSelector<int>(
              label: 'Tipo de actividad',
              value: _selectedPlatform,
              options: const [
                _SegmentOption(value: 0, label: 'Presencial'),
                _SegmentOption(value: 1, label: 'Virtual'),
              ],
              onChanged: isLoading
                  ? null
                  : (v) => setState(() {
                        _selectedPlatform = v;
                        // Reset image when switching to presencial
                        if (v == 0) {
                          _uploadedImageUrl = null;
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
                        _ActivityImagePicker(
                          imageUrl: _uploadedImageUrl,
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
// Widget de selección y previsualización de imagen
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityImagePicker extends StatelessWidget {
  final String? imageUrl;
  final bool isUploading;
  final bool enabled;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;

  const _ActivityImagePicker({
    required this.imageUrl,
    required this.isUploading,
    required this.enabled,
    required this.onPickGallery,
    required this.onPickCamera,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          'Imagen de la actividad',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),

        // Container body
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          decoration: BoxDecoration(
            color: enabled ? c.surface : c.surfaceVariant,
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            border: Border.all(
              color: imageUrl != null
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : c.border,
              width: imageUrl != null ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: context.sac.shadow,
                offset: const Offset(0, 3),
                blurRadius: 20,
              ),
            ],
          ),
          child: isUploading
              ? _UploadingBody()
              : imageUrl != null
                  ? _PreviewBody(
                      imageUrl: imageUrl!,
                      enabled: enabled,
                      onPickGallery: onPickGallery,
                      onPickCamera: onPickCamera,
                    )
                  : _PickerBody(
                      enabled: enabled,
                      onPickGallery: onPickGallery,
                      onPickCamera: onPickCamera,
                    ),
        ),
      ],
    );
  }
}

class _UploadingBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LinearProgressIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.primaryLight,
          ),
          const SizedBox(height: 10),
          Text(
            'Subiendo imagen...',
            style: TextStyle(
              fontSize: 13,
              color: c.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerBody extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;

  const _PickerBody({
    required this.enabled,
    required this.onPickGallery,
    required this.onPickCamera,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _ImageSourceButton(
              icon: HugeIcons.strokeRoundedImage01,
              label: 'Galeria',
              enabled: enabled,
              onTap: onPickGallery,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ImageSourceButton(
              icon: HugeIcons.strokeRoundedCamera01,
              label: 'Camara',
              enabled: enabled,
              onTap: onPickCamera,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageSourceButton extends StatelessWidget {
  final dynamic icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _ImageSourceButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: icon,
              size: 24,
              color: AppColors.primary,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewBody extends StatelessWidget {
  final String imageUrl;
  final bool enabled;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;

  const _PreviewBody({
    required this.imageUrl,
    required this.enabled,
    required this.onPickGallery,
    required this.onPickCamera,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail with re-pick overlay
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    height: 120,
                    color: AppColors.primaryLight,
                    child: const Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedImage01,
                        size: 32,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
              // Re-pick button (top-right corner)
              if (enabled)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _RepickMenu(
                    onPickGallery: onPickGallery,
                    onPickCamera: onPickCamera,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Success text
          Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: AppColors.secondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Imagen cargada correctamente',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RepickMenu extends StatelessWidget {
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;

  const _RepickMenu({
    required this.onPickGallery,
    required this.onPickCamera,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'gallery') onPickGallery();
        if (value == 'camera') onPickCamera();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'gallery',
          child: Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedImage01,
                size: 18,
                color: AppColors.primary,
              ),
              SizedBox(width: 10),
              Text('Galeria'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'camera',
          child: Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedCamera01,
                size: 18,
                color: AppColors.primary,
              ),
              SizedBox(width: 10),
              Text('Camara'),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const HugeIcon(
          icon: HugeIcons.strokeRoundedEdit02,
          size: 16,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets de apoyo internos
// ─────────────────────────────────────────────────────────────────────────────

/// Cabecera de sección con icono y label
class _SectionHeader extends StatelessWidget {
  final dynamic icon;
  final String label;

  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: HugeIcon(icon: icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: c.text,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: c.divider, height: 1)),
      ],
    );
  }
}

/// Opcion de selector segmentado
class _SegmentOption<T> {
  final T value;
  final String label;
  const _SegmentOption({required this.value, required this.label});
}

/// Selector segmentado tipo toggle-chip horizontal
class _SegmentedSelector<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<_SegmentOption<T>> options;
  final void Function(T)? onChanged;

  const _SegmentedSelector({
    required this.label,
    required this.value,
    required this.options,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: options.map((opt) {
            final isSelected = opt.value == value;
            return Expanded(
              child: GestureDetector(
                onTap: onChanged != null ? () => onChanged!(opt.value) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : c.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : c.border,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: context.sac.shadow,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    opt.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : c.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Campo tappable de selección de ubicación
// ─────────────────────────────────────────────────────────────────────────────

/// Campo que muestra la ubicación seleccionada o un placeholder,
/// y abre [LocationPickerView] al ser pulsado.
///
/// Sigue el mismo estilo visual de [SacTextField]:
/// - Label externo sobre el campo
/// - Container con sombra suave
/// - Error en texto rojo debajo
class _LocationPickerField extends StatelessWidget {
  final LocationPickerResult? result;
  final bool hasError;
  final bool enabled;
  final VoidCallback? onTap;

  const _LocationPickerField({
    required this.result,
    required this.hasError,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final theme = Theme.of(context);
    final hasResult = result != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label — igual que SacTextField
        Text(
          'Lugar de la actividad *',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),

        // Contenedor tappable con el mismo estilo de SacTextField
        GestureDetector(
          onTap: enabled ? onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: enabled ? c.surface : c.surfaceVariant,
              boxShadow: [
                BoxShadow(
                  color: c.shadow,
                  offset: const Offset(0, 3),
                  blurRadius: 20,
                ),
              ],
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              border: hasError
                  ? Border.all(color: theme.colorScheme.error, width: 1.5)
                  : hasResult
                      ? Border.all(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          width: 1.5,
                        )
                      : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icono de ubicación
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: HugeIcon(
                    icon: hasResult
                        ? HugeIcons.strokeRoundedLocation01
                        : HugeIcons.strokeRoundedLocation03,
                    size: 20,
                    color: hasResult ? AppColors.primary : c.textSecondary,
                  ),
                ),

                // Texto de la ubicación o placeholder
                Expanded(
                  child: hasResult
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              result!.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: c.text,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${result!.lat.toStringAsFixed(5)}, ${result!.long.toStringAsFixed(5)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: c.textTertiary,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                          ],
                        )
                      : Text(
                          'Seleccionar lugar en el mapa',
                          style: TextStyle(
                            fontSize: 14,
                            color: c.textTertiary,
                          ),
                        ),
                ),

                // Chevron indicador de que es tappable
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: c.textSecondary,
                ),
              ],
            ),
          ),
        ),

        // Error debajo — igual que SacTextField
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 6),
            child: Text(
              'Selecciona el lugar de la actividad',
              style: TextStyle(
                color: theme.colorScheme.error,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
