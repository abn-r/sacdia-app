import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/profile_providers.dart';

/// Vista para editar el perfil del usuario
class EditProfileView extends ConsumerStatefulWidget {
  const EditProfileView({super.key});

  @override
  ConsumerState<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends ConsumerState<EditProfileView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _paternalSurnameController = TextEditingController();
  final _maternalSurnameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  void _loadProfileData() {
    final profile = ref.read(profileNotifierProvider).value;
    if (profile != null) {
      _nameController.text = profile.name;
      _paternalSurnameController.text = profile.paternalSurname ?? '';
      _maternalSurnameController.text = profile.maternalSurname ?? '';
      _phoneController.text = profile.phone ?? '';
      _addressController.text = profile.address ?? '';
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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final data = {
      'name': _nameController.text.trim(),
      'p_lastname': _paternalSurnameController.text.trim(),
      'm_lastname': _maternalSurnameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'address': _addressController.text.trim(),
    };

    final success = await ref
        .read(profileNotifierProvider.notifier)
        .updateProfile(data);

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Perfil actualizado correctamente'),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error al actualizar el perfil'),
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

  InputDecoration _fieldDecoration({
    required String label,
    required dynamic prefixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(prefixIcon, color: AppColors.primary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Editar Perfil'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SacCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sección header
                    Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedUser,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Información Personal',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: _fieldDecoration(
                        label: 'Nombre',
                        prefixIcon: HugeIcons.strokeRoundedUser,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingresa tu nombre';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _paternalSurnameController,
                      decoration: _fieldDecoration(
                        label: 'Apellido Paterno',
                        prefixIcon: HugeIcons.strokeRoundedUser,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _maternalSurnameController,
                      decoration: _fieldDecoration(
                        label: 'Apellido Materno',
                        prefixIcon: HugeIcons.strokeRoundedUser,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: _fieldDecoration(
                        label: 'Teléfono',
                        prefixIcon: HugeIcons.strokeRoundedCall,
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController,
                      decoration: _fieldDecoration(
                        label: 'Dirección',
                        prefixIcon: HugeIcons.strokeRoundedLocation01,
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SacButton.primary(
                text: 'Guardar cambios',
                icon: HugeIcons.strokeRoundedFloppyDisk,
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _saveProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
