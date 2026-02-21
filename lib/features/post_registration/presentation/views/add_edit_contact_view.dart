import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sac_dropdown_field.dart';
import '../../../../core/widgets/sac_text_field.dart';
import '../../data/models/emergency_contact_model.dart';
import '../providers/personal_info_providers.dart';

/// Vista para agregar o editar un contacto de emergencia
class AddEditContactView extends ConsumerStatefulWidget {
  final EmergencyContactModel? contact;

  const AddEditContactView({
    super.key,
    this.contact,
  });

  @override
  ConsumerState<AddEditContactView> createState() => _AddEditContactViewState();
}

class _AddEditContactViewState extends ConsumerState<AddEditContactView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedRelationshipTypeId;
  bool _isPrimary = false;
  bool _isLoading = false;

  bool get _isEditing => widget.contact != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameController.text = widget.contact!.name;
      _phoneController.text = widget.contact!.phone;
      _selectedRelationshipTypeId = widget.contact!.relationshipTypeId;
      _isPrimary = widget.contact!.primary;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRelationshipTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un tipo de relación')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final contact = EmergencyContactModel(
        id: widget.contact?.id,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        relationshipTypeId: _selectedRelationshipTypeId!,
        primary: _isPrimary,
      );

      final notifier = ref.read(emergencyContactsProvider.notifier);

      if (_isEditing) {
        final contactId = widget.contact!.id;
        if (contactId == null) {
          throw Exception(
              'No se pudo obtener el ID del contacto. Intenta cerrar y abrir la pantalla.');
        }
        await notifier.updateContact(contactId, contact);
      } else {
        await notifier.addContact(contact);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Contacto actualizado correctamente'
                  : 'Contacto agregado correctamente',
            ),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final relationshipTypesAsync = ref.watch(relationshipTypesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Contacto' : 'Agregar Contacto'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: SacLoadingSmall(),
                ),
              ),
            )
          else
            IconButton(
              icon: HugeIcon(icon: HugeIcons.strokeRoundedTick02, size: 24),
              onPressed: _handleSave,
              tooltip: 'Guardar',
            ),
        ],
      ),
      body: relationshipTypesAsync.when(
        loading: () => const Center(child: SacLoading()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                  icon: HugeIcons.strokeRoundedAlert02,
                  size: 48,
                  color: AppColors.error),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: HugeIcon(icon: HugeIcons.strokeRoundedRefresh, size: 20),
                label: const Text('Reintentar'),
                onPressed: () => ref.refresh(relationshipTypesProvider),
              ),
            ],
          ),
        ),
        data: (relationshipTypes) => Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Nombre
              SacTextField(
                controller: _nameController,
                label: 'Nombre completo',
                hint: 'Ej: Juan Pérez González',
                prefixIcon: HugeIcons.strokeRoundedUser,
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El nombre es requerido';
                  }
                  if (value.trim().length < 3) {
                    return 'El nombre debe tener al menos 3 caracteres';
                  }
                  return null;
                },
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),

              // Tipo de relación
              SacDropdownField<String>(
                value: _selectedRelationshipTypeId,
                label: 'Tipo de relación',
                hint: 'Selecciona un tipo de relación',
                prefixIcon: HugeIcons.strokeRoundedUserGroup,
                enabled: !_isLoading,
                items: relationshipTypes.map((type) {
                  return DropdownMenuItem(
                    value: type.id,
                    child: Text(type.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRelationshipTypeId = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Selecciona un tipo de relación';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Contacto primario
              Container(
                decoration: BoxDecoration(
                  color: _isPrimary ? AppColors.primaryLight : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      offset: const Offset(0, 3),
                      blurRadius: 20,
                    ),
                  ],
                  border: _isPrimary
                      ? Border.all(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          width: 1.5,
                        )
                      : null,
                ),
                child: SwitchListTile(
                  value: _isPrimary,
                  onChanged: _isLoading
                      ? null
                      : (value) => setState(() => _isPrimary = value),
                  title: const Text(
                    'Contacto primario',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Se notificará primero en caso de emergencia',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.lightTextSecondary,
                    ),
                  ),
                  secondary: HugeIcon(
                    icon: _isPrimary
                        ? HugeIcons.strokeRoundedStar
                        : HugeIcons.strokeRoundedStar,
                    size: 24,
                    color: _isPrimary
                        ? AppColors.primary
                        : AppColors.lightTextSecondary,
                  ),
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.primary,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor:
                      AppColors.lightTextTertiary.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Teléfono
              SacTextField(
                controller: _phoneController,
                label: 'Teléfono',
                hint: 'Ej: 5512345678',
                prefixIcon: HugeIcons.strokeRoundedCall,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El teléfono es requerido';
                  }
                  final phoneRegex = RegExp(r'^\d{10}$');
                  if (!phoneRegex.hasMatch(value.trim())) {
                    return 'Ingresa un teléfono válido de 10 dígitos';
                  }
                  return null;
                },
                enabled: !_isLoading,
              ),
              const SizedBox(height: 24),

              // Botón de guardar
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  icon: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: SacLoadingSmall(),
                        )
                      : HugeIcon(
                          icon: HugeIcons.strokeRoundedFloppyDisk, size: 22),
                  label: Text(
                      _isEditing ? 'Actualizar Contacto' : 'Guardar Contacto'),
                  onPressed: _isLoading ? null : _handleSave,
                ),
              ),

              const SizedBox(height: 16),

              // Nota informativa
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HugeIcon(
                        icon: HugeIcons.strokeRoundedInformationCircle,
                        color: AppColors.primaryDark,
                        size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'El contacto de emergencia será notificado en caso de alguna eventualidad.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
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
