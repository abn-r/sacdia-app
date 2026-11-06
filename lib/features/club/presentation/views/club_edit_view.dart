import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/animations/page_transitions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_dialog.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_network_image.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../../core/widgets/sac_text_field.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../activities/presentation/views/location_picker_view.dart';
import '../../domain/entities/club_info.dart';
import '../providers/club_providers.dart';

/// Opens the club editor over Mi club. Resolves to true when it saved.
///
/// [clubLat]/[clubLong] are the club's own coordinates: the map picker starts
/// there when the section has no location yet.
Future<bool> showClubEditView(
  BuildContext context,
  ClubSection section, {
  double? clubLat,
  double? clubLong,
}) async {
  final saved = await Navigator.of(context, rootNavigator: true).push<bool>(
    SacSlideUpRoute(
      fullscreenDialog: true,
      builder: (_) => ClubEditView(
        section: section,
        clubLat: clubLat,
        clubLong: clubLong,
      ),
    ),
  );
  return saved ?? false;
}

/// Director's editor: «Cancelar» and «Guardar» on top, like editing a
/// contact. Name and club type are not editable, so they are not shown.
class ClubEditView extends ConsumerStatefulWidget {
  const ClubEditView({
    super.key,
    required this.section,
    this.clubLat,
    this.clubLong,
  });

  final ClubSection section;
  final double? clubLat;
  final double? clubLong;

  @override
  ConsumerState<ClubEditView> createState() => _ClubEditViewState();
}

class _ClubEditViewState extends ConsumerState<ClubEditView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _websiteController;
  late final TextEditingController _logoUrlController;

  LocationPickerResult? _location;
  bool _dirty = false;

  static final _emailPattern =
      RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');

  @override
  void initState() {
    super.initState();
    final s = widget.section;
    _addressController = TextEditingController(text: s.address ?? '');
    _phoneController = TextEditingController(text: s.phone ?? '');
    _emailController = TextEditingController(text: s.email ?? '');
    _websiteController = TextEditingController(text: s.website ?? '');
    _logoUrlController = TextEditingController(text: s.logoUrl ?? '');
    // The section's own location first; otherwise the club's, so the
    // director sees (and saves) where the club already is.
    final lat = s.lat ?? (s.long == null ? widget.clubLat : null);
    final long = s.long ?? (s.lat == null ? widget.clubLong : null);
    if (lat != null && long != null) {
      _location = LocationPickerResult(
        name: s.address?.trim() ?? '',
        lat: lat,
        long: long,
      );
      if (_location!.name.isEmpty) _resolveAddress(lat, long);
    }
  }

  /// Fills the address field for a location saved without a name.
  /// Falls back to the coordinates when the device geocoder fails.
  Future<void> _resolveAddress(double lat, double long) async {
    var label = '${lat.toStringAsFixed(5)}, ${long.toStringAsFixed(5)}';
    try {
      final places = await Geocoding().placemarkFromCoordinates(lat, long);
      if (places.isNotEmpty) {
        final p = places.first;
        final parts = [p.thoroughfare, p.subLocality, p.locality]
            .whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList();
        if (parts.isNotEmpty) label = parts.join(', ');
      }
    } catch (_) {
      // No geocoder (offline, simulator): coordinates are enough.
    }
    if (!mounted || _location == null || _addressController.text.isNotEmpty) {
      return;
    }
    if (_location!.lat != lat || _location!.long != long) return;
    setState(() {
      _location = LocationPickerResult(name: label, lat: lat, long: long);
      _addressController.text = label;
    });
  }

  @override
  void dispose() {
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _logoUrlController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  String? _valueOf(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.of(context).push<LocationPickerResult>(
      SacSlideUpRoute(
        builder: (_) => LocationPickerView(
          initialLocation: _location != null
              ? LatLng(_location!.lat, _location!.long)
              : (widget.clubLat != null && widget.clubLong != null)
                  ? LatLng(widget.clubLat!, widget.clubLong!)
                  : null,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _location = result;
      _addressController.text = result.name;
      _dirty = true;
    });
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final discard = await SacDialog.show(
      context,
      title: 'club.unsaved_changes_title'.tr(),
      content: 'club.discard_changes_body'.tr(),
      confirmLabel: 'club.discard'.tr(),
      cancelLabel: 'club.edit.keep_editing'.tr(),
      confirmIsDestructive: true,
    );
    return discard ?? false;
  }

  Future<void> _cancel() async {
    final nav = Navigator.of(context);
    if (await _confirmDiscard() && mounted) nav.pop(false);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final section = widget.section;
    final success = await ref.read(updateClubNotifierProvider.notifier).save(
          clubId: section.mainClubId,
          sectionId: section.id,
          phone: _valueOf(_phoneController),
          email: _valueOf(_emailController),
          website: _valueOf(_websiteController),
          logoUrl: _valueOf(_logoUrlController),
          address: _location?.name,
          lat: _location?.lat,
          long: _location?.long,
        );
    if (!success || !mounted) return;
    ref.invalidate(currentClubSectionProvider);
    Navigator.of(context).pop(true);
  }

  String? _validateUrl(String? value, String errorKey) {
    if (value == null || value.trim().isEmpty) return null;
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme) return errorKey.tr();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    final saving = ref.watch(updateClubNotifierProvider).isLoading;

    ref.listen<UpdateClubState>(updateClubNotifierProvider, (prev, next) {
      final message = next.errorMessage;
      if (message != null && message != prev?.errorMessage) {
        SacSnackBar.show(context, message, isError: true);
      }
    });

    final barTextStyle = TextButton.styleFrom(
      minimumSize: const Size(44, 44),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      textStyle: const TextStyle(fontSize: SacFontSize.titleMedium),
    );

    return PopScope(
      canPop: !_dirty && !saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || saving) return;
        final nav = Navigator.of(context);
        if (await _confirmDiscard() && mounted) nav.pop(false);
      },
      child: Scaffold(
        backgroundColor: c.background,
        appBar: SacTopBar(
          title: 'club.edit.title'.tr(),
          centerTitle: true,
          leadingWidth: 104,
          leading: Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('club-edit-cancel'),
              onPressed: saving ? null : _cancel,
              style: barTextStyle.copyWith(
                foregroundColor: WidgetStatePropertyAll(c.textSecondary),
              ),
              child: Text('common.cancel'.tr()),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: saving
                  ? const SizedBox(
                      width: 72,
                      child: Center(child: SacLoadingSmall()),
                    )
                  : TextButton(
                      key: const ValueKey('club-edit-save'),
                      onPressed: _dirty ? _save : null,
                      style: barTextStyle.copyWith(
                        foregroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.disabled)
                              ? c.textTertiary
                              : accent.color,
                        ),
                        textStyle: const WidgetStatePropertyAll(
                          TextStyle(
                            fontSize: SacFontSize.titleMedium,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      child: Text('common.save'.tr()),
                    ),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              SacTextField(
                controller: _addressController,
                label: 'club.address_label'.tr(),
                hint: 'club.select_address_map'.tr(),
                prefixIcon: HugeIcons.strokeRoundedLocation01,
                readOnly: true,
                enabled: !saving,
                onTap: saving ? null : _pickLocation,
                suffix: HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  size: 18,
                  color: c.textTertiary,
                ),
              ),
              const SizedBox(height: 28),
              _SectionLabel('club.section.contact'.tr()),
              SacTextField(
                controller: _phoneController,
                label: 'club.phone'.tr(),
                hint: 'club.phone_hint'.tr(),
                prefixIcon: HugeIcons.strokeRoundedCall,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                enabled: !saving,
                onChanged: (_) => _markDirty(),
              ),
              const SizedBox(height: 12),
              SacTextField(
                controller: _emailController,
                label: 'club.email'.tr(),
                hint: 'club.email_hint'.tr(),
                prefixIcon: HugeIcons.strokeRoundedMail01,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enabled: !saving,
                onChanged: (_) => _markDirty(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  return _emailPattern.hasMatch(value.trim())
                      ? null
                      : 'club.validation.invalid_email'.tr();
                },
              ),
              const SizedBox(height: 12),
              SacTextField(
                controller: _websiteController,
                label: 'club.website'.tr(),
                hint: 'club.website_hint'.tr(),
                prefixIcon: HugeIcons.strokeRoundedGlobe02,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enabled: !saving,
                onChanged: (_) => _markDirty(),
                validator: (v) =>
                    _validateUrl(v, 'club.validation.invalid_url'),
              ),
              const SizedBox(height: 28),
              SacTextField(
                controller: _logoUrlController,
                label: 'club.logo_url'.tr(),
                hint: 'club.logo_url_hint'.tr(),
                helperText: 'club.edit.logo_helper'.tr(),
                prefixIcon: HugeIcons.strokeRoundedLink01,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enabled: !saving,
                onChanged: (_) => _markDirty(),
                validator: (v) =>
                    _validateUrl(v, 'club.validation.invalid_url_short'),
              ),
              ListenableBuilder(
                listenable: _logoUrlController,
                builder: (context, _) {
                  final url = _logoUrlController.text.trim();
                  final uri = Uri.tryParse(url);
                  if (url.isEmpty || uri == null || !uri.hasScheme) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _LogoPreview(url: url),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: SacFontSize.labelSmall,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: context.sac.textTertiary,
        ),
      ),
    );
  }
}

class _LogoPreview extends StatelessWidget {
  const _LogoPreview({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Center(
      child: Container(
        width: 88,
        height: 88,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          border: Border.all(color: c.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: SacNetworkImage(
          imageUrl: url,
          fit: BoxFit.contain,
          memCacheWidth: 264,
          memCacheHeight: 264,
          errorWidget: (_, __, ___) => Center(
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedImage01,
              size: 28,
              color: c.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}
