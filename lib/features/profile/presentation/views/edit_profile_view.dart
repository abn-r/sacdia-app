import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_text_field.dart';
import '../providers/profile_providers.dart';

/// Vista para editar el perfil del usuario.
///
/// Diseño mobile-first: secciones agrupadas al estilo iOS Settings,
/// avatar en el header, CTA "Guardar" en zona pulgar.
class EditProfileView extends ConsumerStatefulWidget {
  const EditProfileView({super.key});

  @override
  ConsumerState<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends ConsumerState<EditProfileView> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
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
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final data = {
      'name': _nameController.text.trim(),
      'p_lastname': _paternalSurnameController.text.trim(),
      'm_lastname': _maternalSurnameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'address': _addressController.text.trim(),
    };

    final success =
        await ref.read(profileNotifierProvider.notifier).updateProfile(data);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      _showSnackbar(
        'Perfil actualizado correctamente',
        AppColors.secondary,
        HugeIcons.strokeRoundedCheckmarkCircle02,
      );
      Navigator.pop(context);
    } else {
      _showSnackbar(
        'Error al actualizar el perfil',
        AppColors.error,
        HugeIcons.strokeRoundedAlert02,
      );
    }
  }

  void _showSnackbar(String message, Color color, dynamic icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            HugeIcon(icon: icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileNotifierProvider);
    final profile = profileState.value;
    final hPad = Responsive.horizontalPadding(context);

    return Scaffold(
      backgroundColor: context.sac.surfaceVariant,
      // ── AppBar minimalista: sin color relleno, sólo título + back ──
      appBar: AppBar(
        backgroundColor: context.sac.background,
        foregroundColor: context.sac.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: context.sac.text,
            size: 22,
          ),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Volver',
        ),
        title: Text(
          'Editar Perfil',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: context.sac.text,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: context.sac.border),
        ),
      ),

      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 1. Header: avatar + nombre actual ───────────────────
              _AvatarHeader(
                name: profile?.fullName ?? '',
                avatar: profile?.avatar,
                onChangeTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Cambio de foto próximamente'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── 2. Sección: Nombre ────────────────────────────────
              Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                      icon: HugeIcons.strokeRoundedUser,
                      label: 'Nombre',
                    ),
                    const SizedBox(height: 6),
                    SacTextField(
                      controller: _nameController,
                      label: 'Nombre(s)',
                      hint: 'Tu nombre',
                      prefixIcon: HugeIcons.strokeRoundedUser,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'El nombre es requerido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SacTextField(
                            controller: _paternalSurnameController,
                            label: 'Apellido Paterno',
                            hint: 'Primer apellido',
                            prefixIcon: HugeIcons.strokeRoundedUser,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SacTextField(
                            controller: _maternalSurnameController,
                            label: 'Apellido Materno',
                            hint: 'Segundo apellido',
                            prefixIcon: HugeIcons.strokeRoundedUser,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── 3. Sección: Contacto ───────────────────────
                    _SectionHeader(
                      icon: HugeIcons.strokeRoundedCall,
                      label: 'Contacto',
                    ),
                    const SizedBox(height: 10),
                    _FormCard(
                      children: [
                        SacTextField(
                          controller: _phoneController,
                          label: 'Teléfono',
                          hint: '+52 55 1234 5678',
                          prefixIcon: HugeIcons.strokeRoundedCall,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[\d\s\+\-\(\)]'),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── 4. Sección: Ubicación ──────────────────────
                    _SectionHeader(
                      icon: HugeIcons.strokeRoundedLocation01,
                      label: 'Ubicación',
                    ),
                    const SizedBox(height: 10),
                    _FormCard(
                      children: [
                        SacTextField(
                          controller: _addressController,
                          label: 'Dirección',
                          hint: 'Tu dirección completa',
                          prefixIcon: HugeIcons.strokeRoundedLocation01,
                          maxLines: 3,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.done,
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // ── 5. CTA Guardar (thumb zone) ───────────────
                    SacButton.primary(
                      text: 'Guardar cambios',
                      icon: HugeIcons.strokeRoundedFloppyDisk,
                      isLoading: _isLoading,
                      onPressed: _isLoading ? null : _saveProfile,
                    ),

                    const SizedBox(height: 12),

                    // Cancelar secundario
                    SacButton.outline(
                      text: 'Cancelar',
                      onPressed: () => Navigator.pop(context),
                    ),

                    const SizedBox(height: 32),
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

// ─── Private Widgets ────────────────────────────────────────────────────────

/// Header con avatar circular y nombre actual del usuario.
/// El ícono de cámara indica que la foto es editable (próximamente).
class _AvatarHeader extends StatelessWidget {
  final String name;
  final String? avatar;
  final VoidCallback? onChangeTap;

  const _AvatarHeader({
    required this.name,
    this.avatar,
    this.onChangeTap,
  });

  @override
  Widget build(BuildContext context) {
    const double radius = 48.0;

    return Container(
      color: AppColors.lightBackground,
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          // Avatar con botón cámara
          GestureDetector(
            onTap: onChangeTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primaryLight,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: radius,
                    backgroundColor: AppColors.primarySurface,
                    backgroundImage:
                        avatar != null ? NetworkImage(avatar!) : null,
                    child: avatar == null
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'U',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                  ),
                ),
                // Camera badge
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.lightBackground,
                        width: 2,
                      ),
                    ),
                    child: const Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedCamera01,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Nombre actual
          if (name.isNotEmpty)
            Text(
              name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.lightText,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),

          const SizedBox(height: 4),

          // Hint acción foto
          GestureDetector(
            onTap: onChangeTap,
            child: const Text(
              'Cambiar foto de perfil',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Encabezado de sección con icono y etiqueta uppercase.
class _SectionHeader extends StatelessWidget {
  final dynamic icon;
  final String label;

  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: HugeIcon(
              icon: icon,
              color: AppColors.primaryDark,
              size: 15,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.lightTextSecondary,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

/// Contenedor blanco redondeado que agrupa campos de formulario.
class _FormCard extends StatelessWidget {
  final List<Widget> children;

  const _FormCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lightBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}