import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Widget para seleccionar y mostrar la foto de perfil
///
/// Muestra opciones para tomar foto o seleccionar de galería.
class ProfilePhotoPicker extends StatelessWidget {
  /// Path de la imagen seleccionada (null si no hay imagen)
  final String? imagePath;

  /// Callback al seleccionar "Tomar fotografía"
  final VoidCallback onTakePhoto;

  /// Callback al seleccionar "Seleccionar de galería"
  final VoidCallback onPickFromGallery;

  /// Callback al confirmar la imagen
  final VoidCallback? onConfirm;

  /// Callback al eliminar la imagen seleccionada
  final VoidCallback? onRemove;

  /// Indica si se está subiendo la imagen
  final bool isUploading;

  const ProfilePhotoPicker({
    super.key,
    this.imagePath,
    required this.onTakePhoto,
    required this.onPickFromGallery,
    this.onConfirm,
    this.onRemove,
    this.isUploading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 20),

        // Título
        Text(
          'Elige tu fotografía de perfil',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 8),

        Text(
          'Esta foto será visible para los directivos de tu club',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 32),

        // Preview de la imagen o placeholder
        if (imagePath != null) ...[
          // Imagen seleccionada
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: SizedBox(
              width: 200,
              height: 200,
              child: isUploading
                  ? Stack(
                      children: [
                        Image.file(
                          File(imagePath!),
                          fit: BoxFit.cover,
                          width: 200,
                          height: 200,
                        ),
                        Container(
                          color: Colors.black.withOpacity(0.5),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Image.file(
                      File(imagePath!),
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          const SizedBox(height: 24),

          // Botones de acción para imagen seleccionada
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (onRemove != null)
                TextButton.icon(
                  onPressed: isUploading ? null : onRemove,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text(
                    'Eliminar',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: isUploading ? null : onPickFromGallery,
                icon: const Icon(Icons.refresh),
                label: const Text('Cambiar'),
              ),
            ],
          ),
        ] else ...[
          // Placeholder cuando no hay imagen
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[200],
              border: Border.all(color: Colors.grey[400]!, width: 2),
            ),
            child: Icon(
              Icons.person,
              size: 100,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 32),

          // Botones para seleccionar imagen
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onTakePhoto,
                    icon: const Icon(Icons.camera_alt, color: Colors.white),
                    label: const Text(
                      'Tomar fotografía',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sacGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onPickFromGallery,
                    icon: const Icon(Icons.photo_library),
                    label: const Text(
                      'Seleccionar de galería',
                      style: TextStyle(fontSize: 16),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.sacGreen),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
