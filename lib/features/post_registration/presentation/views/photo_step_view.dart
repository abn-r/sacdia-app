import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/post_registration_providers.dart';
import '../widgets/profile_photo_picker.dart';

/// Vista del paso 1 del post-registro: Fotografía de perfil
///
/// Permite al usuario tomar una foto o seleccionar una de la galería,
/// recortarla en formato cuadrado y subirla al servidor.
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
          const SnackBar(
            content: Text('Error al acceder a la cámara'),
            backgroundColor: Colors.red,
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
          const SnackBar(
            content: Text('Error al acceder a la galería'),
            backgroundColor: Colors.red,
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
            toolbarColor: AppColors.sacGreen,
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
        // Subir foto al servidor
        await _uploadPhoto(croppedFile.path);
      }
    } catch (e) {
      log('Error al recortar imagen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al recortar la imagen'),
            backgroundColor: Colors.red,
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
                backgroundColor: Colors.red,
              ),
            );
            // Limpiar foto seleccionada en caso de error
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

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
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
