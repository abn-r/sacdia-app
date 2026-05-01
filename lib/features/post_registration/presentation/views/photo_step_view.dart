import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/utils/app_logger.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/post_registration_providers.dart';
import '../widgets/profile_photo_picker.dart';

/// Vista del paso 1 del post-registro: Fotografía de perfil
///
/// Permite al usuario tomar una foto o seleccionar una de la galería,
/// recortarla en formato cuadrado y subirla al servidor.
/// Horizontal padding adapts via Responsive.horizontalPadding.
class PhotoStepView extends ConsumerStatefulWidget {
  const PhotoStepView({super.key});

  @override
  ConsumerState<PhotoStepView> createState() => _PhotoStepViewState();
}

class _PhotoStepViewState extends ConsumerState<PhotoStepView> {
  static const _tag = 'PhotoStep';
  final ImagePicker _picker = ImagePicker();

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (photo != null) {
        await _cropAndSetImage(photo.path);
      }
    } catch (e) {
      AppLogger.e('Error al tomar foto', tag: _tag, error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('post_registration.photo.errors.camera'.tr()),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (photo != null) {
        await _cropAndSetImage(photo.path);
      }
    } catch (e) {
      AppLogger.e('Error al seleccionar foto', tag: _tag, error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('post_registration.photo.errors.gallery'.tr()),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  Future<void> _cropAndSetImage(String imagePath) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imagePath,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 70,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'post_registration.photo.crop_title'.tr(),
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'post_registration.photo.crop_title'.tr(),
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (croppedFile != null) {
        ref.read(selectedPhotoPathProvider.notifier).state = croppedFile.path;
        await _uploadPhoto(croppedFile.path);
      }
    } catch (e) {
      AppLogger.e('Error al recortar imagen', tag: _tag, error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('post_registration.photo.errors.crop'.tr()),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  Future<void> _uploadPhoto(String filePath) async {
    final authState = ref.read(authNotifierProvider);
    final user = authState.valueOrNull;
    if (user == null) return;

    ref.read(isUploadingPhotoProvider.notifier).state = true;

    try {
      final result = await ref
          .read(postRegistrationRepositoryProvider)
          .uploadProfilePicture(userId: user.id, filePath: filePath);

      result.fold(
        (failure) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('post_registration.photo.errors.upload'.tr(namedArgs: {'message': failure.message})),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            );
            ref.read(selectedPhotoPathProvider.notifier).state = null;
          }
        },
        (url) {
          AppLogger.i('Foto subida exitosamente', tag: _tag);
        },
      );
    } finally {
      if (mounted) {
        ref.read(isUploadingPhotoProvider.notifier).state = false;
      }
    }
  }

  void _removePhoto() {
    ref.read(selectedPhotoPathProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context) {
    final selectedPhoto = ref.watch(selectedPhotoPathProvider);
    final isUploading = ref.watch(isUploadingPhotoProvider);
    final hPad = Responsive.horizontalPadding(context);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 16),
      child: ProfilePhotoPicker(
        imagePath: selectedPhoto,
        isUploading: isUploading,
        onTakePhoto: _takePhoto,
        onPickFromGallery: _pickFromGallery,
        onRemove: _removePhoto,
      ),
    );
  }
}
