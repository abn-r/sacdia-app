import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/animations/page_transitions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_text_field.dart';
import '../../../activities/presentation/views/location_picker_view.dart';
import '../../domain/entities/club_info.dart';
import '../providers/club_providers.dart';

/// Pantalla principal del módulo Club.
///
/// - Director / Subdirector: ve la información y puede editarla.
/// - Resto de roles: vista de solo lectura.
///
/// Ruta: /home/club
class ClubView extends ConsumerStatefulWidget {
  const ClubView({super.key});

  @override
  ConsumerState<ClubView> createState() => _ClubViewState();
}

class _ClubViewState extends ConsumerState<ClubView> {
  // ── Form ─────────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();

  // Controladores de texto
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _logoUrlController = TextEditingController();

  // Ubicación seleccionada
  LocationPickerResult? _selectedLocation;

  // Estado de edición
  bool _isEditing = false;
  bool _hasUnsavedChanges = false;

  // Snapshot de la sección cargada (para comparar cambios)
  ClubSection? _loadedSection;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _logoUrlController.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Rellena los controladores con los datos de la sección.
  void _populateFields(ClubSection section) {
    _loadedSection = section;
    _nameController.text = section.name ?? '';
    _phoneController.text = section.phone ?? '';
    _emailController.text = section.email ?? '';
    _websiteController.text = section.website ?? '';
    _logoUrlController.text = section.logoUrl ?? '';

    final newLocation = (section.lat != null && section.long != null)
        ? LocationPickerResult(
            name: section.address ?? '',
            lat: section.lat!,
            long: section.long!,
          )
        : null;

    if (_selectedLocation != newLocation) {
      setState(() => _selectedLocation = newLocation);
    }
  }

  void _markChanged() {
    if (!_hasUnsavedChanges) setState(() => _hasUnsavedChanges = true);
  }

  Future<bool> _confirmDiscard() async {
    if (!_hasUnsavedChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cambios sin guardar'),
        content: const Text(
          '¿Deseas descartar los cambios realizados?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Descartar',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _openLocationPicker() async {
    final result = await Navigator.push<LocationPickerResult>(
      context,
      SacSlideUpRoute(
        builder: (_) => LocationPickerView(
          initialLocation: _selectedLocation != null
              ? LatLng(_selectedLocation!.lat, _selectedLocation!.long)
              : null,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedLocation = result;
        _hasUnsavedChanges = true;
      });
    }
  }

  Future<void> _handleSave(ClubSection section) async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    final notifier = ref.read(updateClubNotifierProvider.notifier);

    final success = await notifier.save(
      clubId: section.mainClubId,
      sectionId: section.id,
      name: _nameController.text.trim().isEmpty
          ? null
          : _nameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      website: _websiteController.text.trim().isEmpty
          ? null
          : _websiteController.text.trim(),
      logoUrl: _logoUrlController.text.trim().isEmpty
          ? null
          : _logoUrlController.text.trim(),
      address: _selectedLocation?.name,
      lat: _selectedLocation?.lat,
      long: _selectedLocation?.long,
    );

    if (!mounted) return;

    if (success) {
      setState(() {
        _isEditing = false;
        _hasUnsavedChanges = false;
      });

      // Actualizar con los datos devueltos por el servidor
      final updatedSection =
          ref.read(updateClubNotifierProvider).updatedSection;
      if (updatedSection != null) {
        _populateFields(updatedSection);
      }

      // Invalidar el provider de la instancia para refrescar en el próximo acceso
      ref.invalidate(currentClubSectionProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Información del club actualizada'),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
    // El error se muestra via ref.listen en build()
  }

  Future<void> _cancelEdit() async {
    final discard = await _confirmDiscard();
    if (!discard || !mounted) return;

    setState(() {
      _isEditing = false;
      _hasUnsavedChanges = false;
    });

    // Restaurar valores originales
    if (_loadedSection != null) _populateFields(_loadedSection!);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final sectionAsync = ref.watch(currentClubSectionProvider);
    final canEditAsync = ref.watch(canEditClubProvider);
    final updateState = ref.watch(updateClubNotifierProvider);
    final isUpdating = updateState.isLoading;

    // Escuchar errores del notifier de actualización
    ref.listen<UpdateClubState>(updateClubNotifierProvider, (prev, next) {
      if (next.errorMessage != null &&
          next.errorMessage != prev?.errorMessage) {
        _showError(next.errorMessage!);
      }
    });

    return PopScope(
      // Interceptar el botón físico de atrás cuando hay cambios sin guardar
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && _hasUnsavedChanges) {
          final nav = Navigator.of(context);
          final discard = await _confirmDiscard();
          if (discard && mounted) {
            nav.pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: c.background,
        appBar: _buildAppBar(context, c, canEditAsync, sectionAsync, isUpdating),
        body: sectionAsync.when(
          loading: () => const Center(child: SacLoading()),
          error: (error, _) => _ErrorBody(
            message: error.toString(),
            onRetry: () => ref.invalidate(currentClubSectionProvider),
          ),
          data: (section) {
            if (section == null) {
              return _EmptyBody(c: c);
            }

            // Poblar campos la primera vez que llegan los datos o cuando
            // cambia la sección. Se llama desde postFrameCallback para no
            // mutar estado durante el build.
            if (_loadedSection == null || _loadedSection!.id != section.id) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _populateFields(section);
              });
            }

            return _buildBody(context, c, section, isUpdating);
          },
        ),
      ),
    );
  }

  AppBar _buildAppBar(
    BuildContext context,
    SacColors c,
    AsyncValue<bool> canEditAsync,
    AsyncValue<ClubSection?> sectionAsync,
    bool isUpdating,
  ) {
    final canEdit = canEditAsync.valueOrNull ?? false;

    return AppBar(
      backgroundColor: c.background,
      foregroundColor: c.text,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: HugeIcon(
          icon: HugeIcons.strokeRoundedArrowLeft01,
          color: c.text,
          size: 22,
        ),
        onPressed: isUpdating
            ? null
            : () async {
                final nav = Navigator.of(context);
                if (_hasUnsavedChanges) {
                  final discard = await _confirmDiscard();
                  if (discard && mounted) nav.maybePop();
                } else {
                  nav.maybePop();
                }
              },
        tooltip: 'Volver',
      ),
      title: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedBuilding01,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'MI CLUB',
                style: TextStyle(
                  color: c.text,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (sectionAsync.valueOrNull?.clubTypeName != null)
                Text(
                  sectionAsync.valueOrNull!.clubTypeName,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: [
        if (canEdit && !_isEditing)
          IconButton(
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedPencilEdit01,
              color: AppColors.primary,
              size: 22,
            ),
            onPressed:
                isUpdating ? null : () => setState(() => _isEditing = true),
            tooltip: 'Editar',
          ),
        if (_isEditing)
          IconButton(
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedCancel01,
              color: c.textSecondary,
              size: 22,
            ),
            onPressed: isUpdating ? null : _cancelEdit,
            tooltip: 'Cancelar',
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: c.border),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    SacColors c,
    ClubSection section,
    bool isUpdating,
  ) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Sección: Información general ─────────────────────────────
          _SectionHeader(
            icon: HugeIcons.strokeRoundedInformationCircle,
            label: 'Información general',
          ),
          const SizedBox(height: 12),

          // Nombre de la instancia
          _isEditing
              ? SacTextField(
                  controller: _nameController,
                  label: 'Nombre del club',
                  hint: 'Ej: Club Halcones',
                  prefixIcon: HugeIcons.strokeRoundedBuilding01,
                  enabled: !isUpdating,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => _markChanged(),
                )
              : _InfoRow(
                  icon: HugeIcons.strokeRoundedBuilding01,
                  label: 'Nombre',
                  value: section.name ?? '—',
                ),

          const SizedBox(height: 16),

          // Tipo de sección (solo lectura)
          _InfoRow(
            icon: HugeIcons.strokeRoundedUserGroup,
            label: 'Tipo de club',
            value: section.clubTypeName,
          ),

          const SizedBox(height: 24),

          // ── Sección: Dirección ────────────────────────────────────────
          _SectionHeader(
            icon: HugeIcons.strokeRoundedLocation01,
            label: 'Dirección',
          ),
          const SizedBox(height: 12),

          _isEditing
              ? _LocationPickerField(
                  result: _selectedLocation,
                  enabled: !isUpdating,
                  onTap: isUpdating ? null : _openLocationPicker,
                )
              : _InfoRow(
                  icon: HugeIcons.strokeRoundedLocation01,
                  label: 'Dirección',
                  value: section.address ?? '—',
                  subValue: (section.lat != null && section.long != null)
                      ? '${section.lat!.toStringAsFixed(5)}, '
                          '${section.long!.toStringAsFixed(5)}'
                      : null,
                ),

          const SizedBox(height: 24),

          // ── Sección: Contacto ─────────────────────────────────────────
          _SectionHeader(
            icon: HugeIcons.strokeRoundedCall,
            label: 'Contacto',
          ),
          const SizedBox(height: 12),

          // Teléfono
          _isEditing
              ? SacTextField(
                  controller: _phoneController,
                  label: 'Teléfono',
                  hint: '+52 55 0000 0000',
                  prefixIcon: HugeIcons.strokeRoundedCall,
                  keyboardType: TextInputType.phone,
                  enabled: !isUpdating,
                  onChanged: (_) => _markChanged(),
                )
              : _InfoRow(
                  icon: HugeIcons.strokeRoundedCall,
                  label: 'Teléfono',
                  value: section.phone ?? '—',
                ),

          const SizedBox(height: 16),

          // Email
          _isEditing
              ? SacTextField(
                  controller: _emailController,
                  label: 'Correo electrónico',
                  hint: 'club@ejemplo.com',
                  prefixIcon: HugeIcons.strokeRoundedMail01,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !isUpdating,
                  onChanged: (_) => _markChanged(),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final emailRegex = RegExp(
                        r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
                    if (!emailRegex.hasMatch(value.trim())) {
                      return 'Ingresa un correo válido';
                    }
                    return null;
                  },
                )
              : _InfoRow(
                  icon: HugeIcons.strokeRoundedMail01,
                  label: 'Correo electrónico',
                  value: section.email ?? '—',
                ),

          const SizedBox(height: 16),

          // Sitio web
          _isEditing
              ? SacTextField(
                  controller: _websiteController,
                  label: 'Sitio web',
                  hint: 'https://miclub.com',
                  prefixIcon: HugeIcons.strokeRoundedGlobe02,
                  keyboardType: TextInputType.url,
                  enabled: !isUpdating,
                  onChanged: (_) => _markChanged(),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final uri = Uri.tryParse(value.trim());
                    if (uri == null || !uri.hasScheme) {
                      return 'Ingresa una URL válida (ej: https://...)';
                    }
                    return null;
                  },
                )
              : _InfoRow(
                  icon: HugeIcons.strokeRoundedGlobe02,
                  label: 'Sitio web',
                  value: section.website ?? '—',
                ),

          const SizedBox(height: 24),

          // ── Sección: Imagen / Logo ─────────────────────────────────────
          if (_isEditing) ...[
            _SectionHeader(
              icon: HugeIcons.strokeRoundedImage01,
              label: 'Logo del club',
            ),
            const SizedBox(height: 12),
            SacTextField(
              controller: _logoUrlController,
              label: 'URL del logo',
              hint: 'https://cdn.ejemplo.com/logo.png',
              prefixIcon: HugeIcons.strokeRoundedLink01,
              keyboardType: TextInputType.url,
              enabled: !isUpdating,
              onChanged: (_) => _markChanged(),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return null;
                final uri = Uri.tryParse(value.trim());
                if (uri == null || !uri.hasScheme) {
                  return 'Ingresa una URL válida';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
          ] else if (section.logoUrl != null) ...[
            _SectionHeader(
              icon: HugeIcons.strokeRoundedImage01,
              label: 'Logo del club',
            ),
            const SizedBox(height: 12),
            _LogoPreview(logoUrl: section.logoUrl!),
            const SizedBox(height: 24),
          ],

          // ── Botón de guardar (solo en modo edición) ───────────────────
          if (_isEditing) ...[
            SacButton.primary(
              text: 'Guardar cambios',
              icon: HugeIcons.strokeRoundedTick02,
              isLoading: isUpdating,
              isEnabled: !isUpdating,
              onPressed: () => _handleSave(section),
            ),
            const SizedBox(height: 12),
            SacButton.outline(
              text: 'Cancelar',
              isEnabled: !isUpdating,
              onPressed: isUpdating ? null : _cancelEdit,
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets internos de apoyo
// ─────────────────────────────────────────────────────────────────────────────

/// Cabecera de sección con icono y label — mismo estilo que create_activity_view.
class _SectionHeader extends StatelessWidget {
  final HugeIconData icon;
  final String label;

  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: HugeIcon(icon: icon, size: 16, color: AppColors.primary),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: c.text,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: c.divider, height: 1)),
      ],
    );
  }
}

/// Fila de información de solo lectura.
class _InfoRow extends StatelessWidget {
  final HugeIconData icon;
  final String label;
  final String value;
  final String? subValue;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.subValue,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        boxShadow: [
          BoxShadow(
            color: context.sac.shadow,
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 1),
            child: HugeIcon(icon: icon, size: 18, color: c.textSecondary),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: c.textTertiary,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: c.text,
                    height: 1.3,
                  ),
                ),
                if (subValue != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subValue!,
                    style: TextStyle(
                      fontSize: 12,
                      color: c.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo de selección de ubicación — mismo patrón que en create_activity_view.
class _LocationPickerField extends StatelessWidget {
  final LocationPickerResult? result;
  final bool enabled;
  final VoidCallback? onTap;

  const _LocationPickerField({
    required this.result,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final theme = Theme.of(context);
    final hasResult = result != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dirección del club',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: enabled ? onTap : null,
          child: Container(
            decoration: BoxDecoration(
              color: enabled ? c.surface : c.surfaceVariant,
              boxShadow: [
                BoxShadow(
                  color: context.sac.shadow,
                  offset: const Offset(0, 3),
                  blurRadius: 20,
                ),
              ],
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              border: hasResult
                  ? Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      width: 1.5,
                    )
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: HugeIcon(
                    icon: hasResult
                        ? HugeIcons.strokeRoundedLocation01
                        : HugeIcons.strokeRoundedLocation03,
                    size: 20,
                    color: hasResult ? AppColors.primary : c.textSecondary,
                  ),
                ),
                Expanded(
                  child: hasResult
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              result!.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: c.text,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${result!.lat.toStringAsFixed(5)}, '
                              '${result!.long.toStringAsFixed(5)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: c.textTertiary,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                          ],
                        )
                      : Text(
                          'Seleccionar dirección en el mapa',
                          style: TextStyle(fontSize: 14, color: c.textTertiary),
                        ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded,
                    size: 22, color: c.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Vista previa del logo del club.
class _LogoPreview extends StatelessWidget {
  final String logoUrl;

  const _LogoPreview({required this.logoUrl});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Center(
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: c.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: context.sac.shadow,
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: CachedNetworkImage(
          imageUrl: logoUrl,
          fit: BoxFit.cover,
          memCacheWidth: 300,
          memCacheHeight: 300,
          errorWidget: (_, __, ___) => Center(
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedImage01,
              size: 36,
              color: c.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Cuerpo de error con botón de reintento.
class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedAlert02,
              size: 56,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error al cargar el club',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(fontSize: 14, color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SacButton.primary(
              text: 'Reintentar',
              icon: HugeIcons.strokeRoundedRefresh,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

/// Cuerpo vacío — cuando el usuario no tiene contexto de club asignado.
class _EmptyBody extends StatelessWidget {
  final SacColors c;

  const _EmptyBody({required this.c});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedBuilding01,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Sin club asignado',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: c.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No tienes un club asignado en tu perfil. '
              'Completa tu registro de selección de club para acceder a esta sección.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: c.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
