import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_text_field.dart';
import '../../data/models/emergency_contact_model.dart';
import '../../data/models/relationship_type_model.dart';
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
  bool _relationshipError = false;

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
    if (_selectedRelationshipTypeId == null) {
      setState(() => _relationshipError = true);
    }
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;
    if (_selectedRelationshipTypeId == null) return;

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
              _RelationshipPickerField(
                selectedId: _selectedRelationshipTypeId,
                relationshipTypes: relationshipTypes,
                enabled: !_isLoading,
                hasError: _relationshipError,
                onSelected: (id) {
                  setState(() {
                    _selectedRelationshipTypeId = id;
                    _relationshipError = false;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Contacto primario
              Container(
                decoration: BoxDecoration(
                  color: _isPrimary ? AppColors.primaryLight : context.sac.surface,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: context.sac.shadow,
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
                      color: context.sac.textSecondary,
                    ),
                  ),
                  secondary: HugeIcon(
                    icon: _isPrimary
                        ? HugeIcons.strokeRoundedStar
                        : HugeIcons.strokeRoundedStar,
                    size: 24,
                    color: _isPrimary
                        ? AppColors.primary
                        : context.sac.textSecondary,
                  ),
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.primary,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor:
                      context.sac.textTertiary.withValues(alpha: 0.4),
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

// ─────────────────────────────────────────────────────────────────────────────
// Tappable field that opens the RelationshipTypePickerSheet
// ─────────────────────────────────────────────────────────────────────────────

class _RelationshipPickerField extends StatelessWidget {
  final String? selectedId;
  final List<RelationshipTypeModel> relationshipTypes;
  final bool enabled;
  final bool hasError;
  final void Function(String id) onSelected;

  const _RelationshipPickerField({
    required this.selectedId,
    required this.relationshipTypes,
    required this.onSelected,
    this.enabled = true,
    this.hasError = false,
  });

  String? get _selectedName {
    if (selectedId == null) return null;
    final match = relationshipTypes.where((t) => t.id == selectedId);
    return match.isEmpty ? null : match.first.name;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _selectedName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tipo de relación',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: enabled
              ? () async {
                  await showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => _RelationshipTypePickerSheet(
                      relationshipTypes: relationshipTypes,
                      selectedId: selectedId,
                      onSelected: (id) {
                        onSelected(id);
                        Navigator.of(context).pop();
                      },
                    ),
                  );
                }
              : null,
          child: Container(
            decoration: BoxDecoration(
              color: enabled ? context.sac.surface : context.sac.surfaceVariant,
              boxShadow: [
                BoxShadow(
                  color: context.sac.shadow,
                  offset: const Offset(0, 3),
                  blurRadius: 20,
                ),
              ],
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              border: hasError
                  ? Border.all(color: theme.colorScheme.error, width: 1.5)
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedUserGroup,
                    size: 20,
                    color: context.sac.textSecondary,
                  ),
                ),
                Expanded(
                  child: Text(
                    label ?? 'Selecciona un tipo de relación',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: label != null
                          ? context.sac.text
                          : context.sac.textTertiary,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: context.sac.textSecondary,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 6),
            child: Text(
              'Selecciona un tipo de relación',
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

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet with search + list
// ─────────────────────────────────────────────────────────────────────────────

class _RelationshipTypePickerSheet extends StatefulWidget {
  final List<RelationshipTypeModel> relationshipTypes;
  final String? selectedId;
  final void Function(String id) onSelected;

  const _RelationshipTypePickerSheet({
    required this.relationshipTypes,
    required this.onSelected,
    this.selectedId,
  });

  @override
  State<_RelationshipTypePickerSheet> createState() =>
      _RelationshipTypePickerSheetState();
}

class _RelationshipTypePickerSheetState
    extends State<_RelationshipTypePickerSheet> {
  final _searchController = TextEditingController();
  List<RelationshipTypeModel> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.relationshipTypes;
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearch);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? widget.relationshipTypes
          : widget.relationshipTypes
              .where((t) => t.name.toLowerCase().contains(query))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.70),
      decoration: BoxDecoration(
        color: context.sac.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLG),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.sac.border,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
              ),
            ),
          ),

          // Title
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text(
              'Seleccionar relación',
              style: theme.textTheme.headlineSmall,
            ),
          ),

          const Divider(height: 1),

          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Buscar...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusSM),
                  borderSide:
                      BorderSide(color: context.sac.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusSM),
                  borderSide:
                      BorderSide(color: context.sac.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusSM),
                  borderSide: const BorderSide(
                      color: AppColors.primary, width: 2),
                ),
                filled: true,
                fillColor: context.sac.surfaceVariant,
              ),
            ),
          ),

          // List or empty state
          Flexible(
            child: _filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: context.sac.textTertiary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No se encontraron resultados',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: context.sac.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    itemCount: _filtered.length,
                    itemBuilder: (_, index) {
                      final type = _filtered[index];
                      final isSelected =
                          type.id == widget.selectedId;

                      return ListTile(
                        minTileHeight: 48,
                        leading: Icon(
                          Icons.people_outline,
                          size: 22,
                          color: isSelected
                              ? AppColors.primary
                              : context.sac.textSecondary,
                        ),
                        title: Text(
                          type.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isSelected
                                ? AppColors.primary
                                : context.sac.text,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_rounded,
                                color: AppColors.primary,
                                size: 20,
                              )
                            : null,
                        onTap: () => widget.onSelected(type.id),
                      );
                    },
                  ),
          ),

          // Bottom safe-area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}
