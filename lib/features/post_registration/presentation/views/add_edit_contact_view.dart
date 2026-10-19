import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_text_field.dart';
import '../../data/models/emergency_contact_model.dart';
import '../providers/personal_info_providers.dart';
import '../widgets/relationship_type_picker_field.dart';

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
          throw Exception('post_registration.contact_form.error_no_id'.tr());
        }
        await notifier.updateContact(contactId, contact);
      } else {
        await notifier.addContact(contact);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        SacSnackBar.show(
            context,
            _isEditing
                ? 'post_registration.contact_form.contact_updated'.tr()
                : 'post_registration.contact_form.contact_added'.tr(),
            backgroundColor: AppColors.secondary);
      }
    } catch (e) {
      if (mounted) {
        SacSnackBar.show(
            context,
            'post_registration.contact_form.error_saving'
                .tr(namedArgs: {'error': e.toString()}),
            isError: true);
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
      extendBodyBehindAppBar: true,
      appBar: SacTopBar(
          title: _isEditing
              ? 'post_registration.contact_form.edit_title'.tr()
              : 'post_registration.contact_form.add_title'.tr(),
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
              SacPressable(
                listenOnly: true,
                child: IconButton(
                  enableFeedback: false,
                  icon: HugeIcon(icon: HugeIcons.strokeRoundedTick02, size: 24),
                  onPressed: _handleSave,
                  tooltip: 'post_registration.contact_form.save_tooltip'.tr(),
                ),
              ),
          ],
          frosted: true),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => relationshipTypesAsync.when(
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
                  Text(
                    'post_registration.contact_form.error_loading'
                        .tr(namedArgs: {'error': error.toString()}),
                  ),
                  const SizedBox(height: 16),
                  SacButton(
                    text: 'common.retry'.tr(),
                    icon: HugeIcons.strokeRoundedRefresh,
                    onPressed: () => ref.refresh(relationshipTypesProvider),
                  ),
                ],
              ),
            ),
            data: (relationshipTypes) => Form(
              key: _formKey,
              child: ListView(
                padding: SacTopBar.paddingBelowBar(
                    context, const EdgeInsets.all(16)),
                children: [
                  // Nombre
                  SacTextField(
                    controller: _nameController,
                    label: 'post_registration.contact_form.name_label'.tr(),
                    hint: 'post_registration.contact_form.name_hint'.tr(),
                    prefixIcon: HugeIcons.strokeRoundedUser,
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'post_registration.contact_form.name_required'
                            .tr();
                      }
                      if (value.trim().length < 3) {
                        return 'post_registration.contact_form.name_min_length'
                            .tr();
                      }
                      return null;
                    },
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 16),

                  // Tipo de relación
                  RelationshipTypePickerField(
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
                      color: _isPrimary
                          ? SacAccent.of(context).light
                          : context.sac.surface,
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
                              color: SacAccent.of(context)
                                  .color
                                  .withValues(alpha: 0.4),
                              width: 1.5,
                            )
                          : null,
                    ),
                    child: SacPressable(
                      listenOnly: true,
                      child: SwitchListTile(
                        enableFeedback: false,
                        value: _isPrimary,
                        onChanged: _isLoading
                            ? null
                            : (value) => setState(() => _isPrimary = value),
                        title: Text(
                          'post_registration.contact_form.primary_title'.tr(),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'post_registration.contact_form.primary_subtitle'
                              .tr(),
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
                              ? SacAccent.of(context).color
                              : context.sac.textSecondary,
                        ),
                        activeThumbColor: Colors.white,
                        activeTrackColor: SacAccent.of(context).color,
                        inactiveThumbColor: Colors.white,
                        inactiveTrackColor:
                            context.sac.textTertiary.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Teléfono
                  SacTextField(
                    controller: _phoneController,
                    label: 'post_registration.contact_form.phone_label'.tr(),
                    hint: 'post_registration.contact_form.phone_hint'.tr(),
                    prefixIcon: HugeIcons.strokeRoundedCall,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'post_registration.contact_form.phone_required'
                            .tr();
                      }
                      final phoneRegex = RegExp(r'^\d{10}$');
                      if (!phoneRegex.hasMatch(value.trim())) {
                        return 'post_registration.contact_form.phone_invalid'
                            .tr();
                      }
                      return null;
                    },
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 24),

                  // Botón de guardar
                  SacButton.primary(
                    text: _isEditing
                        ? 'post_registration.contact_form.update_button'.tr()
                        : 'post_registration.contact_form.save_button'.tr(),
                    icon: HugeIcons.strokeRoundedFloppyDisk,
                    isLoading: _isLoading,
                    onPressed: _isLoading ? null : _handleSave,
                  ),

                  const SizedBox(height: 16),

                  // Nota informativa
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: SacAccent.of(context).light,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: SacAccent.of(context)
                              .color
                              .withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HugeIcon(
                            icon: HugeIcons.strokeRoundedInformationCircle,
                            color: SacAccent.of(context).dark,
                            size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'post_registration.contact_form.info_note'.tr(),
                            style: TextStyle(
                              fontSize: 12,
                              color: SacAccent.of(context).dark,
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
        ),
      ),
    );
  }
}
