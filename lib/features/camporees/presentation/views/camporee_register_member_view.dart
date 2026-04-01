import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';

import '../providers/camporees_providers.dart';

// Cross-feature dependency note:
// This view intentionally does NOT import [membersNotifierProvider] from the
// members feature. Registration is performed via a direct UUID text input,
// keeping the camporees feature self-contained and safe for deep-link navigation.
// If a member-picker UI is added in the future, it should either:
//   a) Create a scoped [camporeeEligibleMembersProvider] inside this feature
//      (preferred — avoids implicit members-feature activation), or
//   b) Document the cross-feature dependency here with the reasons why a
//      full members fetch is acceptable in that context.

/// Vista para registrar un miembro en un camporee.
///
/// Solicita el UUID del usuario, el tipo de camporee (local/union),
/// el nombre del club (opcional) y el ID de seguro (opcional).
/// Muestra un mensaje específico si el backend responde con error de seguro.
class CamporeeRegisterMemberView extends ConsumerStatefulWidget {
  final int camporeeId;

  const CamporeeRegisterMemberView({
    super.key,
    required this.camporeeId,
  });

  @override
  ConsumerState<CamporeeRegisterMemberView> createState() =>
      _CamporeeRegisterMemberViewState();
}

class _CamporeeRegisterMemberViewState
    extends ConsumerState<CamporeeRegisterMemberView> {
  final _formKey = GlobalKey<FormState>();
  final _userIdController = TextEditingController();
  final _clubNameController = TextEditingController();
  final _insuranceIdController = TextEditingController();

  String _camporeeType = 'local';

  @override
  void dispose() {
    _userIdController.dispose();
    _clubNameController.dispose();
    _insuranceIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final registrationState = ref.watch(
        camporeeRegistrationNotifierProvider(widget.camporeeId));
    final c = context.sac;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: const Text('Inscribir miembro'),
        backgroundColor: c.surface,
        foregroundColor: c.text,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedInformationCircle,
                        size: 18,
                        color: AppColors.accentDark,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Para registrar un miembro necesitás su ID de usuario. '
                          'El seguro de tipo CAMPOREE es necesario para validar la inscripción.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.accentDark,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Error de seguro (banner especial)
                if (registrationState.isInsuranceError &&
                    registrationState.errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedAlert02,
                          size: 20,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Error de seguro',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.error,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'El miembro no tiene un seguro de tipo CAMPOREE '
                                'activo y válido. Verificá que el seguro exista, '
                                'sea de tipo CAMPOREE, esté activo y cubra las '
                                'fechas del camporee.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.error,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Error genérico
                if (!registrationState.isInsuranceError &&
                    registrationState.errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      registrationState.errorMessage!,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ID de usuario
                _FieldLabel(
                    label: 'ID de usuario',
                    required: true,
                    icon: HugeIcons.strokeRoundedUser),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _userIdController,
                  decoration: _inputDecoration(
                    hintText: 'UUID del usuario (ej. xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)',
                    context: context,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El ID de usuario es obligatorio';
                    }
                    // Basic UUID format check
                    final uuidRegex = RegExp(
                      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
                      caseSensitive: false,
                    );
                    if (!uuidRegex.hasMatch(value.trim())) {
                      return 'Ingresa un UUID válido';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Tipo de camporee
                _FieldLabel(
                    label: 'Tipo de camporee',
                    required: true,
                    icon: HugeIcons.strokeRoundedAward01),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: c.border),
                    borderRadius: BorderRadius.circular(12),
                    color: c.surface,
                  ),
                  child: Column(
                    children: [
                      _RadioOption(
                        value: 'local',
                        groupValue: _camporeeType,
                        label: 'Local',
                        description: 'Camporee organizado a nivel de campo local',
                        onChanged: (v) => setState(() => _camporeeType = v!),
                      ),
                      Divider(height: 1, color: c.border),
                      _RadioOption(
                        value: 'union',
                        groupValue: _camporeeType,
                        label: 'Unión',
                        description: 'Camporee organizado a nivel de unión',
                        onChanged: (v) => setState(() => _camporeeType = v!),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Nombre del club (opcional)
                _FieldLabel(
                    label: 'Nombre del club',
                    required: false,
                    icon: HugeIcons.strokeRoundedBuilding01),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _clubNameController,
                  decoration: _inputDecoration(
                    hintText: 'Nombre del club (requerido para unión)',
                    context: context,
                  ),
                ),

                const SizedBox(height: 20),

                // ID de seguro (opcional)
                _FieldLabel(
                    label: 'ID de seguro',
                    required: false,
                    icon: HugeIcons.strokeRoundedShield01),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _insuranceIdController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration(
                    hintText: 'ID del seguro de tipo CAMPOREE (opcional)',
                    context: context,
                  ),
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final parsed = int.tryParse(value);
                      if (parsed == null || parsed <= 0) {
                        return 'Ingresa un ID de seguro válido';
                      }
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // Botón registrar
                SacButton.primary(
                  text: 'Registrar miembro',
                  icon: HugeIcons.strokeRoundedUserAdd01,
                  isLoading: registrationState.isLoading,
                  onPressed: registrationState.isLoading
                      ? null
                      : () => _submit(context),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required BuildContext context,
  }) {
    final c = context.sac;
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(fontSize: 13, color: c.textTertiary),
      filled: true,
      fillColor: c.surface,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.error),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    ref
        .read(camporeeRegistrationNotifierProvider(widget.camporeeId).notifier)
        .reset();

    final userId = _userIdController.text.trim();
    final clubName = _clubNameController.text.trim().isEmpty
        ? null
        : _clubNameController.text.trim();
    final insuranceId = _insuranceIdController.text.trim().isEmpty
        ? null
        : int.tryParse(_insuranceIdController.text.trim());

    final success = await ref
        .read(camporeeRegistrationNotifierProvider(widget.camporeeId).notifier)
        .register(
          userId: userId,
          camporeeType: _camporeeType,
          clubName: clubName,
          insuranceId: insuranceId,
        );

    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Miembro registrado exitosamente'),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      Navigator.pop(context);
    }
  }
}

// ── Field Label ────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool required;
  final HugeIconData icon;

  const _FieldLabel({
    required this.label,
    required this.required,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        HugeIcon(icon: icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: context.sac.text,
          ),
        ),
        if (required) ...[
          const SizedBox(width: 4),
          Text(
            '*',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.error,
            ),
          ),
        ] else ...[
          const SizedBox(width: 6),
          Text(
            '(opcional)',
            style: TextStyle(
              fontSize: 12,
              color: context.sac.textTertiary,
            ),
          ),
        ],
      ],
    );
  }
}

// ── Radio Option ───────────────────────────────────────────────────────────────

class _RadioOption extends StatelessWidget {
  final String value;
  final String groupValue;
  final String label;
  final String description;
  final ValueChanged<String?> onChanged;

  const _RadioOption({
    required this.value,
    required this.groupValue,
    required this.label,
    required this.description,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final selected = value == groupValue;

    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Custom radio circle (avoids deprecated groupValue API)
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.primary : context.sac.border,
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? AppColors.primary : c.text,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11,
                      color: c.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
