import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/app_logger.dart';
import 'package:sacdia_app/core/widgets/sac_date_picker.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_grouped_section.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../post_registration/presentation/providers/post_registration_providers.dart';
import '../../domain/entities/user_detail.dart';
import '../providers/profile_providers.dart';
import '../utils/profile_update_payload.dart';
import '../widgets/edit_profile_avatar.dart';
import '../widgets/edit_profile_row.dart';
import '../widgets/gender_selector.dart';
import '../widgets/profile_edit_sheets.dart';
import '../widgets/profile_photo_sheet.dart';

/// Edit profile: grouped rows like Settings. Each row opens a bottom sheet (or
/// the date picker) that edits and saves only that value.
class EditProfileView extends ConsumerStatefulWidget {
  const EditProfileView({super.key});

  @override
  ConsumerState<EditProfileView> createState() => _EditProfileViewState();
}

enum _PhotoBusy { none, uploading, removing }

/// Editable snapshot of the saved profile: the current values plus the one
/// field being changed make up the payload of a single-field save.
class _ProfileFields {
  _ProfileFields.from(UserDetail p)
      : name = p.name,
        paternal = p.paternalSurname ?? '',
        maternal = p.maternalSurname ?? '',
        gender = Gender.fromApiKey(p.gender),
        birthdate = p.birthDate,
        baptized = p.baptized,
        baptismDate = p.baptismDate;

  String name;
  String paternal;
  String maternal;
  Gender? gender;
  DateTime? birthdate;
  bool baptized;
  DateTime? baptismDate;

  Map<String, dynamic> toPayload() => buildProfileUpdatePayload(
        name: name,
        paternalLastName: paternal,
        maternalLastName: maternal,
        gender: gender?.apiKey,
        birthday: birthdate,
        baptism: baptized,
        baptismDate: baptismDate,
      );

  /// Date rules: the birthdate is not in the future; when baptized the
  /// baptism date is required and not before the birthdate.
  String? validateDates() {
    final birth = birthdate;
    if (birth != null && birth.isAfter(DateTime.now())) {
      return tr('profile.edit.birthdate_error_future');
    }
    if (baptized) {
      final baptism = baptismDate;
      if (baptism == null) return tr('profile.edit.baptism_date_error_null');
      if (birth != null && baptism.isBefore(birth)) {
        return tr('profile.edit.baptism_date_error_before_birth');
      }
    }
    return null;
  }
}

class _EditProfileViewState extends ConsumerState<EditProfileView> {
  static const _tag = 'EditProfileView';

  _PhotoBusy _photoBusy = _PhotoBusy.none;

  /// A date or switch save is running: further taps are ignored.
  bool _isSavingInline = false;

  /// Value of the "Baptized" switch while its save is in flight.
  bool? _pendingBaptized;

  /// Last loaded profile: a failed save leaves the provider in error state,
  /// the rows keep showing the saved values.
  UserDetail? _lastProfile;

  UserDetail? get _profile =>
      ref.read(profileNotifierProvider).value ?? _lastProfile;

  // ── Saving one field ──────────────────────────────────────────────────────

  /// Applies [change] to the saved profile and sends the full payload.
  ///
  /// Returns null on success (snackbar shown) or the error message.
  Future<String?> _commit(
    void Function(_ProfileFields fields) change, {
    bool validateDates = false,
  }) async {
    final profile = _profile;
    if (profile == null) return tr('profile.edit.save_error');

    final fields = _ProfileFields.from(profile);
    change(fields);
    if (validateDates) {
      final error = fields.validateDates();
      if (error != null) return error;
    }

    final saved = await ref
        .read(profileNotifierProvider.notifier)
        .updateProfile(fields.toPayload());
    if (!mounted) return null;
    if (!saved) return tr('profile.edit.save_error');

    ref.invalidate(profileNotifierProvider);
    // Navbars and greetings read the auth user: refresh it without waiting for
    // the next /auth/me call. Refresh in place: invalidating would put auth in
    // loading and the router would send the user back to Home.
    ref
        .read(authNotifierProvider.notifier)
        .refreshCurrentUser(keepCurrentOnFailure: true);
    SacSnackBar.show(context, tr('profile.edit.save_success'), isSuccess: true);
    return null;
  }

  /// [_commit] for the rows that have no sheet (dates, switch): an error goes
  /// to a snackbar. Returns true when saved.
  Future<bool> _commitInline(
    void Function(_ProfileFields fields) change,
  ) async {
    setState(() => _isSavingInline = true);
    final error = await _commit(change, validateDates: true);
    if (!mounted) return error == null;
    setState(() => _isSavingInline = false);
    if (error != null) {
      SacSnackBar.show(context, error, isError: true);
    }
    return error == null;
  }

  // ── Text and gender rows (sheets) ─────────────────────────────────────────

  Future<void> _editName() {
    final profile = _profile;
    if (profile == null) return Future.value();
    return showProfileTextSheet(
      context,
      title: tr('profile.edit.field_name_label'),
      helper: tr('profile.edit.field_name_helper'),
      hint: tr('profile.edit.field_name_placeholder'),
      initialValue: profile.name,
      requiredMessage: tr('profile.edit.field_name_required'),
      onSave: (value) => _commit((f) => f.name = value),
    );
  }

  Future<void> _editPaternal() {
    final profile = _profile;
    if (profile == null) return Future.value();
    return showProfileTextSheet(
      context,
      title: tr('profile.edit.field_paternal_label'),
      helper: tr('profile.edit.field_paternal_helper'),
      hint: tr('profile.edit.field_paternal_placeholder'),
      initialValue: profile.paternalSurname ?? '',
      onSave: (value) => _commit((f) => f.paternal = value),
    );
  }

  Future<void> _editMaternal() {
    final profile = _profile;
    if (profile == null) return Future.value();
    return showProfileTextSheet(
      context,
      title: tr('profile.edit.field_maternal_label'),
      helper: tr('profile.edit.field_maternal_helper'),
      hint: tr('profile.edit.field_maternal_placeholder'),
      initialValue: profile.maternalSurname ?? '',
      onSave: (value) => _commit((f) => f.maternal = value),
    );
  }

  Future<void> _editGender() {
    final profile = _profile;
    if (profile == null) return Future.value();
    return showGenderSheet(
      context,
      current: Gender.fromApiKey(profile.gender),
      onSave: (value) => _commit((f) => f.gender = value),
    );
  }

  // ── Date rows (picker straight from the row) ──────────────────────────────

  Future<void> _editBirthdate() async {
    final profile = _profile;
    if (profile == null || _isSavingInline) return;

    final now = DateTime.now();
    final minDate = DateTime(now.year - 99, now.month, now.day);
    final maxDate = DateTime(now.year - 3, now.month, now.day);
    final initialDate = profile.birthDate ?? maxDate;

    final picked = await showSacDatePicker(
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
    if (picked == null || !mounted) return;

    await _commitInline((f) => f.birthdate = picked);
  }

  Future<DateTime?> _pickBaptismDate() {
    final now = DateTime.now();
    final firstDate = _profile?.birthDate ?? DateTime(1900);
    final initialDate = _profile?.baptismDate ?? now;

    return showSacDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstDate) ? firstDate : initialDate,
      firstDate: firstDate,
      lastDate: now,
      helpText: tr('profile.edit.baptism_date_picker_help'),
      cancelText: tr('profile.edit.date_picker_cancel'),
      confirmText: tr('profile.edit.date_picker_confirm'),
    );
  }

  Future<void> _editBaptismDate() async {
    if (_isSavingInline) return;
    final picked = await _pickBaptismDate();
    if (picked == null || !mounted) return;
    await _commitInline((f) => f.baptismDate = picked);
  }

  /// ON needs a baptism date: cancelling the picker leaves the switch off and
  /// saves nothing. OFF saves `baptism: false`.
  Future<void> _toggleBaptized(bool value) async {
    if (_isSavingInline) return;

    DateTime? baptismDate;
    if (value) {
      baptismDate = await _pickBaptismDate();
      if (baptismDate == null || !mounted) return;
    }

    setState(() => _pendingBaptized = value);
    await _commitInline((f) {
      f.baptized = value;
      f.baptismDate = value ? baptismDate : null;
    });
    if (mounted) setState(() => _pendingBaptized = null);
  }

  // ── Photo ─────────────────────────────────────────────────────────────────

  Future<void> _openPhotoSheet() async {
    if (_photoBusy != _PhotoBusy.none) return;

    final avatar = _profile?.avatar;
    final action = await showProfilePhotoSheet(
      context,
      hasPhoto: avatar != null && avatar.isNotEmpty,
    );
    if (action == null || !mounted) return;

    switch (action) {
      case ProfilePhotoAction.camera:
        await _pickAndUpload(ImageSource.camera);
      case ProfilePhotoAction.gallery:
        await _pickAndUpload(ImageSource.gallery);
      case ProfilePhotoAction.remove:
        await _confirmAndRemove();
    }
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    final user = await ref.read(authNotifierProvider.future);
    if (!mounted) return;
    if (user == null) return;

    try {
      final XFile? photo = await ImagePicker().pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (photo == null || !mounted) return; // cancelled at the picker

      final accent = SacAccent.of(context);
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: photo.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 70,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: tr('profile.edit.crop_photo_title'),
            toolbarColor: accent.color,
            toolbarWidgetColor: accent.onColor,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: tr('profile.edit.crop_photo_title'),
            doneButtonTitle: tr('common.done'),
            cancelButtonTitle: tr('common.cancel'),
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );
      if (croppedFile == null || !mounted) return; // cancelled at the cropper

      setState(() => _photoBusy = _PhotoBusy.uploading);
      try {
        final success =
            await ref.read(profilePhotoUploadNotifierProvider.notifier).upload(
                  userId: user.id,
                  filePath: croppedFile.path,
                );
        if (!mounted) return;

        if (!success) {
          _showSnackbar(tr('profile.edit.photo_upload_error'), isError: true);
        } else {
          await _refreshAfterPhotoChange();
          if (!mounted) return;
          _showSnackbar(tr('profile.edit.photo_upload_success'));
        }
      } finally {
        if (mounted) setState(() => _photoBusy = _PhotoBusy.none);
      }
    } catch (e) {
      AppLogger.e('Error al cambiar foto de perfil', tag: _tag, error: e);
      if (mounted) {
        setState(() => _photoBusy = _PhotoBusy.none);
        _showSnackbar(tr('profile.edit.photo_upload_error'), isError: true);
      }
    }
  }

  Future<void> _confirmAndRemove() async {
    final user = await ref.read(authNotifierProvider.future);
    if (!mounted) return;
    if (user == null) return;

    final confirmed = await SacDialog.show(
      context,
      title: tr('profile.edit.photo_remove_confirm_title'),
      content: tr('profile.edit.photo_remove_confirm_body'),
      confirmLabel: tr('profile.edit.photo_remove'),
      confirmIsDestructive: true,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _photoBusy = _PhotoBusy.removing);
    try {
      final success = await ref
          .read(profilePhotoUploadNotifierProvider.notifier)
          .remove(userId: user.id);
      if (!mounted) return;

      if (!success) {
        _showSnackbar(tr('profile.edit.photo_remove_error'), isError: true);
      } else {
        await _refreshAfterPhotoChange();
        if (!mounted) return;
        _showSnackbar(tr('profile.edit.photo_removed'));
      }
    } finally {
      if (mounted) setState(() => _photoBusy = _PhotoBusy.none);
    }
  }

  /// Reloads profile and auth user and waits for the profile, so the avatar
  /// crossfades to the new photo before the ring goes away.
  Future<void> _refreshAfterPhotoChange() async {
    ref.invalidate(profileNotifierProvider);
    // Refresh in place (see [_commit]).
    ref
        .read(authNotifierProvider.notifier)
        .refreshCurrentUser(keepCurrentOnFailure: true);
    try {
      await ref.read(profileNotifierProvider.future);
    } catch (e) {
      AppLogger.e('No se pudo recargar el perfil', tag: _tag, error: e);
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    SacSnackBar.show(
      context,
      message,
      isError: isError,
      isSuccess: !isError,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  String? _formatDate(DateTime? date) => date == null
      ? null
      : DateFormat.yMMMd(context.locale.toString()).format(date);

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileNotifierProvider).value ?? _lastProfile;
    if (profile != null) _lastProfile = profile;

    final baptized = _pendingBaptized ?? profile?.baptized ?? false;
    final addLabel = tr('profile.edit.add_value');
    final gender = Gender.fromApiKey(profile?.gender);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: context.sac.background,
      appBar: SacTopBar(title: tr('profile.edit.title'), frosted: true),
      body: SacFrostedVeil(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(top: SacTopBar.frostedInset(context)),
          physics: const AlwaysScrollableScrollPhysics(),
          child: profile == null
              ? const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: SacLoading()),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    EditProfileAvatar(
                      name: profile.fullName,
                      avatarUrl: (profile.avatar?.isNotEmpty ?? false)
                          ? profile.avatar
                          : null,
                      isBusy: _photoBusy != _PhotoBusy.none,
                      busyLabel: _photoBusy == _PhotoBusy.removing
                          ? tr('profile.edit.photo_removing')
                          : tr('profile.edit.photo_uploading'),
                      onTap: _openPhotoSheet,
                    ),
                    SacGroupedSection(
                      label: tr('profile.edit.group_name'),
                      dividerIndent: 16,
                      children: [
                        EditProfileRow(
                          label: tr('profile.edit.field_name_label'),
                          value: profile.name,
                          emptyLabel: addLabel,
                          onTap: _editName,
                        ),
                        EditProfileRow(
                          label: tr('profile.edit.field_paternal_label'),
                          value: profile.paternalSurname,
                          emptyLabel: addLabel,
                          onTap: _editPaternal,
                        ),
                        EditProfileRow(
                          label: tr('profile.edit.field_maternal_label'),
                          value: profile.maternalSurname,
                          emptyLabel: addLabel,
                          onTap: _editMaternal,
                        ),
                      ],
                    ),
                    SacGroupedSection(
                      label: tr('profile.edit.group_personal'),
                      dividerIndent: 16,
                      children: [
                        EditProfileRow(
                          label: tr('profile.edit.gender_label'),
                          value: gender?.display(context),
                          emptyLabel: addLabel,
                          onTap: _editGender,
                        ),
                        EditProfileRow(
                          label: tr('profile.edit.birthdate_label'),
                          value: _formatDate(profile.birthDate),
                          emptyLabel: addLabel,
                          onTap: _editBirthdate,
                        ),
                      ],
                    ),
                    SacGroupedSection(
                      label: tr('profile.edit.group_church'),
                      dividerIndent: 16,
                      children: [
                        EditProfileSwitchRow(
                          label: tr('profile.edit.baptism_toggle'),
                          value: baptized,
                          onChanged: _isSavingInline ? null : _toggleBaptized,
                        ),
                        if (baptized)
                          EditProfileRow(
                            label: tr('profile.edit.baptism_date_label'),
                            value: _formatDate(profile.baptismDate),
                            emptyLabel: addLabel,
                            onTap: _editBaptismDate,
                          ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
        ),
      ),
    );
  }
}
