import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
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
      log('Error al tomar foto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error al acceder a la cámara'),
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
      log('Error al seleccionar foto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error al acceder a la galería'),
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
            toolbarTitle: 'Recortar foto',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Recortar foto',
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
      log('Error al recortar imagen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error al recortar la imagen'),
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
                content: Text('Error al subir foto: ${failure.message}'),
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
          log('Foto subida exitosamente: $url');
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
