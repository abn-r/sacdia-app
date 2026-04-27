import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:sacdia_app/core/utils/app_logger.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_text_field.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../post_registration/presentation/providers/post_registration_providers.dart';
import '../providers/profile_providers.dart';

/// Vista para editar el perfil del usuario.
///
/// Diseño mobile-first: secciones agrupadas al estilo iOS Settings,
/// avatar en el header, CTA "Guardar" en zona pulgar.
class EditProfileView extends ConsumerStatefulWidget {
  const EditProfileView({super.key});

  @override
  ConsumerState<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends ConsumerState<EditProfileView> {
  static const _tag = 'EditProfileView';

  final _formKey = GlobalKey<FormState>();

  // Controllers — basic profile fields
  final _nameController = TextEditingController();
  final _paternalSurnameController = TextEditingController();
  final _maternalSurnameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  // State — personal info fields (F3)
  String? _selectedGender;
  DateTime? _birthdate;
  bool _baptized = false;
  DateTime? _baptismDate;

  // State — loading flags
  bool _isLoading = false;
  bool _isUploadingPhoto = false;

  // Inline validation error messages
  String? _birthdateError;
  String? _baptismDateError;

  bool _dataLoaded = false;

  @override
  void initState() {
    super.initState();
    // Try loading immediately in case data is already cached
    _loadProfileData();
  }

  void _loadProfileData() {
    if (_dataLoaded) return;
    final profile = ref.read(profileNotifierProvider).value;
    if (profile != null) {
      _dataLoaded = true;
      _nameController.text = profile.name;
      _paternalSurnameController.text = profile.paternalSurname ?? '';
      _maternalSurnameController.text = profile.maternalSurname ?? '';
      _phoneController.text = profile.phone ?? '';
      _addressController.text = profile.address ?? '';

      // Pre-populate personal info fields (F3)
      setState(() {
        _selectedGender = profile.gender;
        _birthdate = profile.birthDate;
        _baptized = profile.baptized;
        _baptismDate = profile.baptismDate;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _paternalSurnameController.dispose();
    _maternalSurnameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // ── F4: Photo change logic ────────────────────────────────────────────────

  Future<void> _changePhoto() async {
    final user = ref.read(authNotifierProvider).valueOrNull;
    if (user == null) return;

    try {
      final XFile? photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (photo == null) return; // User cancelled at picker

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: photo.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 70,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: tr('profile.edit.crop_photo_title'),
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: tr('profile.edit.crop_photo_title'),
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (croppedFile == null) return; // User cancelled at cropper

      setState(() => _isUploadingPhoto = true);

      try {
        final result = await ref
            .read(postRegistrationRepositoryProvider)
            .uploadProfilePicture(
              userId: user.id,
              filePath: croppedFile.path,
            );

        result.fold(
          (failure) {
            if (mounted) {
              _showSnackbar(
                tr('profile.edit.photo_upload_error'),
                AppColors.error,
                HugeIcons.strokeRoundedAlert02,
              );
            }
          },
          (_) {
            if (mounted) {
              ref.invalidate(profileNotifierProvider);
              ref.invalidate(authNotifierProvider);
              _showSnackbar(
                tr('profile.edit.photo_upload_success'),
                AppColors.secondary,
                HugeIcons.strokeRoundedCheckmarkCircle02,
              );
            }
          },
        );
      } finally {
        if (mounted) {
          setState(() => _isUploadingPhoto = false);
        }
      }
    } catch (e) {
      AppLogger.e('Error al cambiar foto de perfil', tag: _tag, error: e);
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        _showSnackbar(
          tr('profile.edit.photo_upload_error'),
          AppColors.error,
          HugeIcons.strokeRoundedAlert02,
        );
      }
    }
  }

  // ── F3 + basic: Save profile ──────────────────────────────────────────────

  /// Validates personal info fields (F3). Returns true if valid.
  bool _validatePersonalInfo() {
    bool valid = true;
    String? newBirthdateError;
    String? newBaptismDateError;

    if (_birthdate != null && _birthdate!.isAfter(DateTime.now())) {
      newBirthdateError = tr('profile.edit.birthdate_error_future');
      valid = false;
    }

    if (_baptized) {
      if (_baptismDate == null) {
        newBaptismDateError = tr('profile.edit.baptism_date_error_null');
        valid = false;
      } else if (_birthdate != null && _baptismDate!.isBefore(_birthdate!)) {
        newBaptismDateError = tr('profile.edit.baptism_date_error_before_birth');
        valid = false;
      }
    }

    setState(() {
      _birthdateError = newBirthdateError;
      _baptismDateError = newBaptismDateError;
    });

    return valid;
  }

  Future<void> _saveProfile() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;
    if (!_validatePersonalInfo()) return;

    setState(() => _isLoading = true);

    bool success = false;

    // Unified update: all fields in a single PATCH /users/:userId
    final data = <String, dynamic>{
      'name': _nameController.text.trim(),
      'paternal_last_name': _paternalSurnameController.text.trim(),
      'maternal_last_name': _maternalSurnameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'address': _addressController.text.trim(),
    };

    // Add personal info fields (F3)
    if (_selectedGender != null) data['gender'] = _selectedGender;
    if (_birthdate != null) {
      data['birthday'] = _birthdate!.toUtc().toIso8601String();
    }
    data['baptism'] = _baptized;
    if (_baptized && _baptismDate != null) {
      data['baptism_date'] = _baptismDate!.toUtc().toIso8601String();
    }

    success =
        await ref.read(profileNotifierProvider.notifier).updateProfile(data);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      ref.invalidate(profileNotifierProvider);
      // Invalidate auth state so any widget reading authNotifierProvider
      // (navbars, dashboard greetings, etc.) reflects the updated name/avatar
      // without waiting for the next /auth/me call on app restart.
      ref.invalidate(authNotifierProvider);
      _showSnackbar(
        tr('profile.edit.save_success'),
        AppColors.secondary,
        HugeIcons.strokeRoundedCheckmarkCircle02,
      );
      Navigator.pop(context);
    } else {
      _showSnackbar(
        tr('profile.edit.save_error'),
        AppColors.error,
        HugeIcons.strokeRoundedAlert02,
      );
    }
  }

  // ── Date pickers (F3) ────────────────────────────────────────────────────

  Future<void> _selectBirthdate() async {
    final now = DateTime.now();
    final minDate = DateTime(now.year - 99, now.month, now.day);
    final maxDate = DateTime(now.year - 3, now.month, now.day);
    final initialDate = _birthdate ?? maxDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(minDate)
          ? minDate
          : (initialDate.isAfter(maxDate) ? maxDate : initialDate),
      firstDate: minDate,
      lastDate: maxDate,
      helpText: tr('profile.edit.birthdate_picker_help'),
      cancelText: tr('profile.edit.date_picker_cancel'),
      confirmText: tr('profile.edit.date_picker_confirm'),
    );

    if (picked != null) {
      setState(() {
        _birthdate = picked;
        _birthdateError = null;
        // Reset baptism date if it becomes invalid
        if (_baptismDate != null && _baptismDate!.isBefore(picked)) {
          _baptismDate = null;
          _baptismDateError = null;
        }
      });
    }
  }

  Future<void> _selectBaptismDate() async {
    final now = DateTime.now();
    final firstDate = _birthdate ?? DateTime(1900);
    final initialDate = _baptismDate ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstDate) ? firstDate : initialDate,
      firstDate: firstDate,
      lastDate: now,
      helpText: tr('profile.edit.baptism_date_picker_help'),
      cancelText: tr('profile.edit.date_picker_cancel'),
      confirmText: tr('profile.edit.date_picker_confirm'),
    );

    if (picked != null) {
      setState(() {
        _baptismDate = picked;
        _baptismDateError = null;
      });
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _showSnackbar(String message, Color color, dynamic icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            HugeIcon(icon: icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileNotifierProvider);
    final profile = profileState.value;
    final hPad = Responsive.horizontalPadding(context);

    // Load data when provider resolves (handles async timing)
    if (!_dataLoaded && profile != null) {
      _loadProfileData();
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.sac.background,
        foregroundColor: context.sac.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: context.sac.text,
            size: 22,
          ),
          onPressed: () => Navigator.pop(context),
          tooltip: tr('profile.edit.back_tooltip'),
        ),
        title: Text(
          tr('profile.edit.title'),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: context.sac.text,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: context.sac.border),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 1. Header: avatar + nombre actual ───────────────────
              _AvatarHeader(
                name: profile?.fullName ?? '',
                avatar: profile?.avatar,
                isUploading: _isUploadingPhoto,
                onChangeTap: _isUploadingPhoto ? null : _changePhoto,
              ),

              const SizedBox(height: 24),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 2. Sección: Nombre ────────────────────────────────
                    _SectionHeader(
                      icon: HugeIcons.strokeRoundedUser,
                      label: tr('profile.edit.section_name'),
                    ),
                    const SizedBox(height: 6),
                    SacTextField(
                      controller: _nameController,
                      label: tr('profile.edit.field_name_label'),
                      hint: tr('profile.edit.field_name_placeholder'),
                      prefixIcon: HugeIcons.strokeRoundedUser,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return tr('profile.edit.field_name_required');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SacTextField(
                            controller: _paternalSurnameController,
                            label: tr('profile.edit.field_paternal_label'),
                            hint: tr('profile.edit.field_paternal_placeholder'),
                            prefixIcon: HugeIcons.strokeRoundedUser,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SacTextField(
                            controller: _maternalSurnameController,
                            label: tr('profile.edit.field_maternal_label'),
                            hint: tr('profile.edit.field_maternal_placeholder'),
                            prefixIcon: HugeIcons.strokeRoundedUser,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── 5. Sección: Información Personal (F3) ─────
                    _SectionHeader(
                      icon: HugeIcons.strokeRoundedUser,
                      label: tr('profile.edit.section_personal_info'),
                    ),
                    const SizedBox(height: 12),

                    // Gender chip selector
                    Text(
                      tr('profile.edit.gender_label'),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: context.sac.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _GenderChip(
                          label: tr('profile.edit.gender_male'),
                          value: 'M',
                          selectedValue: _selectedGender,
                          onTap: () => setState(() => _selectedGender = 'M'),
                        ),
                        const SizedBox(width: 12),
                        _GenderChip(
                          label: tr('profile.edit.gender_female'),
                          value: 'F',
                          selectedValue: _selectedGender,
                          onTap: () => setState(() => _selectedGender = 'F'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Birthdate picker
                    _DatePickerField(
                      label: tr('profile.edit.birthdate_label'),
                      icon: HugeIcons.strokeRoundedBirthdayCake,
                      date: _birthdate,
                      errorText: _birthdateError,
                      onTap: _selectBirthdate,
                    ),

                    const SizedBox(height: 12),

                    // Baptism toggle
                    SacCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: SwitchListTile(
                        title: Text(
                          tr('profile.edit.baptism_toggle'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        value: _baptized,
                        activeTrackColor: AppColors.primaryLight,
                        thumbColor:
                            const WidgetStatePropertyAll(AppColors.primary),
                        contentPadding: EdgeInsets.zero,
                        onChanged: (value) {
                          setState(() {
                            _baptized = value;
                            if (!value) {
                              _baptismDate = null;
                              _baptismDateError = null;
                            }
                          });
                        },
                      ),
                    ),

                    // Conditional baptism date picker
                    if (_baptized) ...[
                      const SizedBox(height: 12),
                      _DatePickerField(
                        label: tr('profile.edit.baptism_date_label'),
                        icon: HugeIcons.strokeRoundedBlood,
                        date: _baptismDate,
                        errorText: _baptismDateError,
                        onTap: _selectBaptismDate,
                      ),
                    ],

                    const SizedBox(height: 32),

                    // ── 6. CTA Guardar (thumb zone) ───────────────
                    SacButton.primary(
                      text: tr('profile.edit.save_changes'),
                      icon: HugeIcons.strokeRoundedFloppyDisk,
                      isLoading: _isLoading,
                      onPressed:
                          (_isLoading || _isUploadingPhoto) ? null : _saveProfile,
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Private Widgets ────────────────────────────────────────────────────────

/// Header con avatar circular y nombre actual del usuario.
/// Muestra indicador de carga durante la subida de foto (F4).
class _AvatarHeader extends StatelessWidget {
  final String name;
  final String? avatar;
  final bool isUploading;
  final VoidCallback? onChangeTap;

  const _AvatarHeader({
    required this.name,
    this.avatar,
    this.isUploading = false,
    this.onChangeTap,
  });

  @override
  Widget build(BuildContext context) {
    const double radius = 48.0;

    return Container(
      color: context.sac.background,
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          GestureDetector(
            onTap: onChangeTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primaryLight,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: radius,
                        backgroundColor: AppColors.primarySurface,
                        backgroundImage: avatar != null
                            ? CachedNetworkImageProvider(avatar!)
                            : null,
                        child: avatar == null
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              )
                            : null,
                      ),
                      if (isUploading)
                        Container(
                          width: radius * 2,
                          height: radius * 2,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0x80000000),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!isUploading)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.sac.background,
                          width: 2,
                        ),
                      ),
                      child: const Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedCamera01,
                          color: Colors.white,
                          size: 15,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          if (name.isNotEmpty)
            Text(
              name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.sac.text,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),

          const SizedBox(height: 4),

          GestureDetector(
            onTap: onChangeTap,
            child: Text(
              isUploading ? tr('profile.edit.photo_uploading') : tr('profile.edit.change_photo'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isUploading
                    ? context.sac.textTertiary
                    : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Encabezado de sección con icono y etiqueta uppercase.
class _SectionHeader extends StatelessWidget {
  final HugeIconData icon;
  final String label;

  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: HugeIcon(
              icon: icon,
              color: AppColors.primaryDark,
              size: 15,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: context.sac.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

/// Chip selector de género (F3).
class _GenderChip extends StatelessWidget {
  final String label;
  final String value;
  final String? selectedValue;
  final VoidCallback onTap;

  const _GenderChip({
    required this.label,
    required this.value,
    required this.selectedValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedValue == value;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight : context.sac.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : context.sac.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedUser,
                size: 20,
                color: isSelected
                    ? AppColors.primary
                    : context.sac.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? AppColors.primary
                      : context.sac.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Campo de selección de fecha con indicador de error inline (F3).
class _DatePickerField extends StatelessWidget {
  final String label;
  final HugeIconData icon;
  final DateTime? date;
  final String? errorText;
  final VoidCallback onTap;

  const _DatePickerField({
    required this.label,
    required this.icon,
    required this.date,
    required this.onTap,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SacCard(
          onTap: onTap,
          borderColor: errorText != null ? AppColors.error : null,
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: errorText != null
                      ? AppColors.errorLight
                      : (date != null
                          ? AppColors.primaryLight
                          : context.sac.surfaceVariant),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: icon,
                    size: 20,
                    color: errorText != null
                        ? AppColors.error
                        : (date != null
                            ? AppColors.primary
                            : context.sac.textTertiary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.sac.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      date != null
                          ? DateFormat('yyyy-MM-dd').format(date!)
                          : tr('profile.edit.date_placeholder'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: date != null
                            ? context.sac.text
                            : context.sac.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              HugeIcon(
                icon: HugeIcons.strokeRoundedCalendar01,
                size: 18,
                color: context.sac.textTertiary,
              ),
            ],
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              errorText!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
