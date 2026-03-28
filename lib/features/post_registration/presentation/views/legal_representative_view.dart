import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/legal_representative_model.dart';
import '../providers/personal_info_providers.dart';

/// Vista para gestionar el representante legal
class LegalRepresentativeView extends ConsumerStatefulWidget {
  const LegalRepresentativeView({super.key});

  @override
  ConsumerState<LegalRepresentativeView> createState() =>
      _LegalRepresentativeViewState();
}

class _LegalRepresentativeViewState
    extends ConsumerState<LegalRepresentativeView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _paternalSurnameController = TextEditingController();
  final _maternalSurnameController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedTypeId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Cargar datos existentes si hay
    Future.microtask(() {
      final repAsync = ref.read(legalRepresentativeProvider);
      repAsync.whenData((rep) {
        if (rep != null && mounted) {
          setState(() {
            _nameController.text = rep.name;
            _paternalSurnameController.text = rep.paternalSurname;
            _maternalSurnameController.text = rep.maternalSurname;
            _phoneController.text = rep.phone;
            // Buscar el ID del tipo de relación que coincida con el nombre guardado
            final typesAsync = ref.read(relationshipTypesProvider);
            typesAsync.whenData((types) {
              final match = types
                  .where((t) => t.name.toLowerCase() == rep.type.toLowerCase());
              if (match.isNotEmpty && mounted) {
                setState(() => _selectedTypeId = match.first.id);
              }
            });
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _paternalSurnameController.dispose();
    _maternalSurnameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Obtener el nombre del tipo seleccionado
      final typesAsync = ref.read(relationshipTypesProvider);
      final types = typesAsync.valueOrNull ?? [];
      final selectedType = types.where((t) => t.id == _selectedTypeId);
      final typeName = selectedType.isNotEmpty ? selectedType.first.name : '';

      final representative = LegalRepresentativeModel(
        name: _nameController.text.trim(),
        paternalSurname: _paternalSurnameController.text.trim(),
        maternalSurname: _maternalSurnameController.text.trim(),
        phone: _phoneController.text.trim(),
        type: typeName,
      );

      await ref
          .read(legalRepresentativeProvider.notifier)
          .saveRepresentative(representative);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Representante legal guardado correctamente'),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.of(context).pop(true);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Representante Legal'),
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Nota informativa
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HugeIcon(
                      icon: HugeIcons.strokeRoundedInformationCircle,
                      color: AppColors.accentDark,
                      size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Los menores de 18 años requieren un representante legal.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.accentDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Tipo de representante - cargado desde la API
            Consumer(
              builder: (context, ref, _) {
                final typesAsync = ref.watch(relationshipTypesProvider);
                return typesAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: SacLoadingSmall(),
                    ),
                  ),
                  error: (error, _) => Text(
                    'Error al cargar tipos: $error',
                    style: const TextStyle(color: AppColors.error),
                  ),
                  data: (types) {
                    // Preseleccionar el primer tipo si no hay selección
                    if (_selectedTypeId == null && types.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() => _selectedTypeId = types.first.id);
                        }
                      });
                    }
                    return DropdownButtonFormField<String>(
                      initialValue: types.any((t) => t.id == _selectedTypeId)
                          ? _selectedTypeId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de representante *',
                        prefixIcon: HugeIcon(
                            icon: HugeIcons.strokeRoundedUserGroup, size: 22),
                        border: OutlineInputBorder(),
                      ),
                      items: types.map((type) {
                        return DropdownMenuItem(
                          value: type.id,
                          child: Text(type.name),
                        );
                      }).toList(),
                      onChanged: _isLoading
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _selectedTypeId = value);
                              }
                            },
                      validator: (value) {
                        if (value == null) {
                          return 'Selecciona un tipo de representante';
                        }
                        return null;
                      },
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),

            // Nombre
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre(s) *',
                hintText: 'Ej: Juan Carlos',
                prefixIcon:
                    HugeIcon(icon: HugeIcons.strokeRoundedUser, size: 22),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El nombre es requerido';
                }
                if (value.trim().length < 2) {
                  return 'El nombre debe tener al menos 2 caracteres';
                }
                return null;
              },
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),

            // Apellido Paterno
            TextFormField(
              controller: _paternalSurnameController,
              decoration: const InputDecoration(
                labelText: 'Apellido Paterno *',
                hintText: 'Ej: Pérez',
                prefixIcon:
                    HugeIcon(icon: HugeIcons.strokeRoundedUser, size: 22),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El apellido paterno es requerido';
                }
                if (value.trim().length < 2) {
                  return 'El apellido debe tener al menos 2 caracteres';
                }
                return null;
              },
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),

            // Apellido Materno
            TextFormField(
              controller: _maternalSurnameController,
              decoration: const InputDecoration(
                labelText: 'Apellido Materno *',
                hintText: 'Ej: González',
                prefixIcon:
                    HugeIcon(icon: HugeIcons.strokeRoundedUser, size: 22),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El apellido materno es requerido';
                }
                if (value.trim().length < 2) {
                  return 'El apellido debe tener al menos 2 caracteres';
                }
                return null;
              },
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),

            // Teléfono
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Teléfono *',
                hintText: 'Ej: 5512345678',
                prefixIcon:
                    HugeIcon(icon: HugeIcons.strokeRoundedCall, size: 22),
                border: OutlineInputBorder(),
              ),
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
                label: const Text('Guardar Representante Legal'),
                onPressed: _isLoading ? null : _handleSave,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
