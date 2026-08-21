import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/animations/motion_tokens.dart';
import '../../../../core/animations/page_transitions.dart';
import '../../../../core/animations/staggered_list_animation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_dialog.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_network_image.dart';
import '../../../../core/widgets/sac_text_field.dart';
import '../../../activities/presentation/views/location_picker_view.dart';
import '../../domain/entities/club_info.dart';
import '../providers/club_providers.dart';

/// Pantalla principal del módulo Club.
///
/// - Director / Subdirector: ve la información y puede editarla.
/// - Resto de roles: vista de solo lectura.
///
/// Vista y edición usan [SacTextField] (readOnly en lectura) para no
/// intercambiar layouts. Ruta: /home/club
class ClubView extends ConsumerStatefulWidget {
  const ClubView({super.key});

  @override
  ConsumerState<ClubView> createState() => _ClubViewState();
}

class _ClubViewState extends ConsumerState<ClubView> {
  // ── Form ─────────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _typeController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _logoUrlController = TextEditingController();

  LocationPickerResult? _selectedLocation;

  bool _isEditing = false;
  bool _hasUnsavedChanges = false;

  ClubSection? _loadedSection;

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _logoUrlController.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _populateFields(ClubSection section, {String? clubName}) {
    _loadedSection = section;
    if (clubName != null) {
      _nameController.text = clubName;
    }
    _typeController.text = section.clubTypeName;
    _addressController.text = section.address ?? '';
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

  void _syncClubName(String? clubName) {
    final next = clubName ?? '';
    if (_nameController.text == next) return;
    _nameController.text = next;
  }

  void _markChanged() {
    if (!_hasUnsavedChanges) setState(() => _hasUnsavedChanges = true);
  }

  Future<bool> _confirmDiscard() async {
    if (!_hasUnsavedChanges) return true;

    final result = await SacDialog.show(
      context,
      title: 'club.unsaved_changes_title'.tr(),
      content: 'club.discard_changes_body'.tr(),
      confirmLabel: 'club.discard'.tr(),
      cancelLabel: 'common.cancel'.tr(),
      confirmIsDestructive: true,
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
        _addressController.text = result.name;
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

      final updatedSection =
          ref.read(updateClubNotifierProvider).updatedSection;
      if (updatedSection != null) {
        _populateFields(
          updatedSection,
          clubName: _nameController.text,
        );
      }

      ref.invalidate(currentClubSectionProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('club.update_success'.tr()),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _cancelEdit() async {
    final discard = await _confirmDiscard();
    if (!discard || !mounted) return;

    setState(() {
      _isEditing = false;
      _hasUnsavedChanges = false;
    });

    if (_loadedSection != null) {
      _populateFields(_loadedSection!, clubName: _nameController.text);
    }
  }

  void _enterEdit() {
    HapticFeedback.lightImpact();
    setState(() => _isEditing = true);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String? _coordsHelper() {
    final loc = _selectedLocation;
    if (loc == null) return null;
    return '${loc.lat.toStringAsFixed(5)}, ${loc.long.toStringAsFixed(5)}';
  }

  String _emptyHint(String editHint) => _isEditing ? editHint : '—';

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final sectionAsync = ref.watch(currentClubSectionProvider);
    final canEditAsync = ref.watch(canEditClubProvider);
    final updateState = ref.watch(updateClubNotifierProvider);
    final isUpdating = updateState.isLoading;

    ref.listen<UpdateClubState>(updateClubNotifierProvider, (prev, next) {
      if (next.errorMessage != null &&
          next.errorMessage != prev?.errorMessage) {
        _showError(next.errorMessage!);
      }
    });

    return PopScope(
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
        backgroundColor: c.surfaceVariant,
        appBar:
            _buildAppBar(context, c, canEditAsync, sectionAsync, isUpdating),
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

            final clubName = section.mainClubId.isEmpty
                ? null
                : ref
                    .watch(clubInfoProvider(section.mainClubId))
                    .valueOrNull
                    ?.name;
            final resolvedName =
                (clubName != null && clubName.trim().isNotEmpty)
                    ? clubName
                    : '';

            if (_loadedSection == null || _loadedSection!.id != section.id) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _populateFields(section, clubName: resolvedName);
                }
              });
            } else if (resolvedName.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _syncClubName(resolvedName);
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
    final section = sectionAsync.valueOrNull;
    String? subtitle;
    if (section != null) {
      final clubName = section.mainClubId.isEmpty
          ? null
          : ref.watch(clubInfoProvider(section.mainClubId)).valueOrNull?.name;
      final label = clubSectionDisplayLabel(clubName, section.clubTypeName);
      subtitle = label.isEmpty ? section.clubTypeName : label;
    }

    return AppBar(
      backgroundColor: c.surfaceVariant,
      foregroundColor: c.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
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
        tooltip: 'common.back'.tr(),
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'club.my_club_title'.tr(),
            style: TextStyle(
              color: c.text,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          if (subtitle != null && subtitle.isNotEmpty)
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w400,
                letterSpacing: 0,
              ),
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
            onPressed: isUpdating ? null : _enterEdit,
            tooltip: 'common.edit'.tr(),
          ),
        if (_isEditing)
          IconButton(
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedCancel01,
              color: c.textSecondary,
              size: 22,
            ),
            onPressed: isUpdating ? null : _cancelEdit,
            tooltip: 'common.cancel'.tr(),
          ),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    SacColors c,
    ClubSection section,
    bool isUpdating,
  ) {
    final fieldsEnabled = !isUpdating;
    final editable = _isEditing && fieldsEnabled;

    return Form(
      key: _formKey,
      child: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(20, 8, 20, _isEditing ? 112 : 32),
            children: [
              _stagger(
                index: 0,
                children: [
                  _SectionHeader(
                    icon: HugeIcons.strokeRoundedInformationCircle,
                    label: 'club.section.general_info'.tr(),
                  ),
                  const SizedBox(height: 12),
                  SacTextField(
                    controller: _nameController,
                    label: 'club.name'.tr(),
                    hint: '—',
                    prefixIcon: HugeIcons.strokeRoundedFlag01,
                    readOnly: true,
                    enabled: fieldsEnabled && !_isEditing,
                  ),
                  const SizedBox(height: 12),
                  SacTextField(
                    controller: _typeController,
                    label: 'club.type_label'.tr(),
                    hint: '—',
                    prefixIcon: HugeIcons.strokeRoundedUserGroup,
                    readOnly: true,
                    enabled: fieldsEnabled && !_isEditing,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _stagger(
                index: 1,
                children: [
                  _SectionHeader(
                    icon: HugeIcons.strokeRoundedLocation01,
                    label: 'club.address'.tr(),
                  ),
                  const SizedBox(height: 12),
                  _ClubPressable(
                    enabled: editable,
                    child: SacTextField(
                      controller: _addressController,
                      label: 'club.address_label'.tr(),
                      hint: _emptyHint('club.select_address_map'.tr()),
                      prefixIcon: HugeIcons.strokeRoundedLocation01,
                      readOnly: true,
                      enabled: fieldsEnabled,
                      helperText: _coordsHelper(),
                      onTap: editable ? _openLocationPicker : null,
                      suffix: _isEditing
                          ? IconButton(
                              icon: HugeIcon(
                                icon: HugeIcons.strokeRoundedArrowRight01,
                                size: 18,
                                color: c.textSecondary,
                              ),
                              onPressed:
                                  editable ? _openLocationPicker : null,
                            )
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _stagger(
                index: 2,
                children: [
                  _SectionHeader(
                    icon: HugeIcons.strokeRoundedCall,
                    label: 'club.section.contact'.tr(),
                  ),
                  const SizedBox(height: 12),
                  SacTextField(
                    controller: _phoneController,
                    label: 'club.phone'.tr(),
                    hint: _emptyHint('club.phone_hint'.tr()),
                    prefixIcon: HugeIcons.strokeRoundedCall,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    readOnly: !_isEditing,
                    enabled: fieldsEnabled,
                    onChanged: _isEditing ? (_) => _markChanged() : null,
                  ),
                  const SizedBox(height: 12),
                  SacTextField(
                    controller: _emailController,
                    label: 'club.email'.tr(),
                    hint: _emptyHint('club.email_hint'.tr()),
                    prefixIcon: HugeIcons.strokeRoundedMail01,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    readOnly: !_isEditing,
                    enabled: fieldsEnabled,
                    onChanged: _isEditing ? (_) => _markChanged() : null,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return null;
                      final emailRegex = RegExp(
                          r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
                      if (!emailRegex.hasMatch(value.trim())) {
                        return 'club.validation.invalid_email'.tr();
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  SacTextField(
                    controller: _websiteController,
                    label: 'club.website'.tr(),
                    hint: _emptyHint('club.website_hint'.tr()),
                    prefixIcon: HugeIcons.strokeRoundedGlobe02,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    readOnly: !_isEditing,
                    enabled: fieldsEnabled,
                    onChanged: _isEditing ? (_) => _markChanged() : null,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return null;
                      final uri = Uri.tryParse(value.trim());
                      if (uri == null || !uri.hasScheme) {
                        return 'club.validation.invalid_url'.tr();
                      }
                      return null;
                    },
                  ),
                ],
              ),
              if (_isEditing ||
                  (section.logoUrl != null &&
                      section.logoUrl!.isNotEmpty)) ...[
                const SizedBox(height: 28),
                _stagger(
                  index: 3,
                  children: [
                    _SectionHeader(
                      icon: HugeIcons.strokeRoundedImage01,
                      label: 'club.logo'.tr(),
                    ),
                    const SizedBox(height: 12),
                    if (_isEditing) ...[
                      SacTextField(
                        controller: _logoUrlController,
                        label: 'club.logo_url'.tr(),
                        hint: 'club.logo_url_hint'.tr(),
                        prefixIcon: HugeIcons.strokeRoundedLink01,
                        keyboardType: TextInputType.url,
                        enabled: fieldsEnabled,
                        onChanged: (_) => _markChanged(),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return null;
                          }
                          final uri = Uri.tryParse(value.trim());
                          if (uri == null || !uri.hasScheme) {
                            return 'club.validation.invalid_url_short'.tr();
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    ListenableBuilder(
                      listenable: _logoUrlController,
                      builder: (context, _) {
                        final url = _logoUrlController.text.trim();
                        if (url.isEmpty) return const SizedBox.shrink();
                        return _LogoPreview(logoUrl: url);
                      },
                    ),
                  ],
                ),
              ],
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _SaveDock(
              visible: _isEditing,
              isUpdating: isUpdating,
              onSave: () => _handleSave(section),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stagger({
    required int index,
    required List<Widget> children,
  }) {
    return StaggeredListItem(
      index: index,
      staggerDelay: SacMotion.stagger,
      duration: SacMotion.standard,
      slideOffset: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets internos de apoyo
// ─────────────────────────────────────────────────────────────────────────────

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
            letterSpacing: -0.2,
            color: c.text,
          ),
        ),
      ],
    );
  }
}

/// Press scale on pointer-down. Does not steal the child's tap.
class _ClubPressable extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const _ClubPressable({
    required this.child,
    required this.enabled,
  });

  @override
  State<_ClubPressable> createState() => _ClubPressableState();
}

class _ClubPressableState extends State<_ClubPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !widget.enabled) return;
    setState(() => _pressed = value);
  }

  @override
  void didUpdateWidget(covariant _ClubPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _pressed) {
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduce = SacMotion.reduceMotionOf(context);
    return Listener(
      onPointerDown: widget.enabled ? (_) => _setPressed(true) : null,
      onPointerUp: widget.enabled ? (_) => _setPressed(false) : null,
      onPointerCancel: widget.enabled ? (_) => _setPressed(false) : null,
      child: AnimatedScale(
        scale: (!reduce && _pressed) ? 0.97 : 1,
        duration: SacMotion.press,
        curve: SacMotion.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Save dock slides from the bottom. Enter 200ms, exit 140ms.
class _SaveDock extends StatelessWidget {
  final bool visible;
  final bool isUpdating;
  final VoidCallback onSave;

  const _SaveDock({
    required this.visible,
    required this.isUpdating,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final reduce = SacMotion.reduceMotionOf(context);
    final duration = visible ? SacMotion.standard : SacMotion.press;

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: (reduce || visible) ? Offset.zero : const Offset(0, 1.1),
        duration: duration,
        curve: SacMotion.easeOut,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: reduce ? SacMotion.reducedFade : duration,
          curve: SacMotion.easeOut,
          child: Material(
            color: c.surface,
            child: Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: c.border)),
                boxShadow: [
                  BoxShadow(
                    color: c.shadow,
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: SacButton.primary(
                text: 'club.save_changes'.tr(),
                icon: HugeIcons.strokeRoundedTick02,
                isLoading: isUpdating,
                isEnabled: !isUpdating,
                onPressed: onSave,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
        child: SacNetworkImage(
          imageUrl: logoUrl,
          fit: BoxFit.contain,
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
              'club.load_error'.tr(),
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
              text: 'common.retry'.tr(),
              icon: HugeIcons.strokeRoundedRefresh,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

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
                  icon: HugeIcons.strokeRoundedFlag01,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'club.no_club_assigned'.tr(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: c.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'club.no_club_description'.tr(),
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 14, color: c.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
