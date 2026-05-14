import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:sacdia_app/features/post_registration/data/models/allergy_model.dart';
import 'package:sacdia_app/features/post_registration/data/models/emergency_contact_model.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/personal_info_providers.dart';
import 'package:sacdia_app/features/profile/domain/entities/user_detail.dart';
import 'package:sacdia_app/features/profile/presentation/providers/profile_providers.dart';

import '../widgets/medico/medico_tokens.dart';
import '../widgets/medico/slide_to_confirm_button.dart';

// ── GPS state machine ──────────────────────────────────────────────────────────
enum _GpsState { idle, acquiring, success, error }

/// Pantalla de emergencia SOS — Variante B (action-heavy).
///
/// Muestra datos médicos críticos del usuario (tipo de sangre, alergias
/// severas, contactos de emergencia) y ofrece CTAs de alta visibilidad
/// para llamar a un contacto, llamar al 911 y compartir ubicación por SMS.
///
/// Lifecycle:
/// - Sube brillo a 100% y activa wakelock al entrar.
/// - Restaura brillo y desactiva wakelock al salir.
class MedicalSosView extends ConsumerStatefulWidget {
  const MedicalSosView({super.key});

  static const routeName = '/profile/medical/sos';

  @override
  ConsumerState<MedicalSosView> createState() => _MedicalSosViewState();
}

class _MedicalSosViewState extends ConsumerState<MedicalSosView>
    with WidgetsBindingObserver {
  double? _previousBrightness;
  _GpsState _gpsState = _GpsState.idle;
  bool _contactsExpanded = false;

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enableWakeAndBrightness();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disableWakeAndBrightness();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _enableWakeAndBrightness();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // OS will reset brightness on its own when app is backgrounded;
      // disable wakelock so battery is not drained in background.
      WakelockPlus.disable().ignore();
    }
  }

  Future<void> _enableWakeAndBrightness() async {
    try {
      await WakelockPlus.enable();
    } catch (_) {}
    try {
      _previousBrightness = await ScreenBrightness().application;
      await ScreenBrightness().setApplicationScreenBrightness(1.0);
    } catch (_) {}
  }

  Future<void> _disableWakeAndBrightness() async {
    try {
      WakelockPlus.disable().ignore();
    } catch (_) {}
    try {
      await ScreenBrightness().resetApplicationScreenBrightness();
    } catch (e) {
      try {
        if (_previousBrightness != null) {
          await ScreenBrightness()
              .setApplicationScreenBrightness(_previousBrightness!);
        }
      } catch (_) {}
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static String _cleanPhone(String p) => p.replaceAll(RegExp(r'[^0-9+]'), '');

  Future<void> _dial(String phone) async {
    final uri = Uri.parse('tel:${_cleanPhone(phone)}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showMaterialBanner(
        MaterialBanner(
          backgroundColor: MedicoTokens.rose500,
          content: Text(
            'profile.medical_info.sos.errors.call_failed'.tr(),
            style: const TextStyle(color: MedicoTokens.paper),
          ),
          actions: [
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                _dial(phone);
              },
              child: Text(
                'profile.medical_info.sos.errors.retry'.tr(),
                style: const TextStyle(color: MedicoTokens.paper),
              ),
            ),
            TextButton(
              onPressed: () =>
                  ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
              child: Text(
                'profile.medical_info.sos.errors.dismiss'.tr(),
                style:
                    TextStyle(color: MedicoTokens.paper.withValues(alpha: 0.7)),
              ),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _dialPrimary(List<EmergencyContactModel> contacts) async {
    HapticFeedback.mediumImpact();
    if (contacts.isEmpty) {
      // No contacts: pop to medical info
      if (mounted) Navigator.of(context).maybePop();
      return;
    }
    // Find primary contact or fall back to first
    final contact = contacts.firstWhere(
      (c) => c.primary,
      orElse: () => contacts.first,
    );
    await _dial(contact.phone);
  }

  Future<void> _dial911() async {
    HapticFeedback.heavyImpact();
    await _dial('911');
  }

  Future<void> _shareGpsLocation(List<EmergencyContactModel> contacts) async {
    if (_gpsState == _GpsState.acquiring) return;

    setState(() => _gpsState = _GpsState.acquiring);

    // Check/request permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      setState(() => _gpsState = _GpsState.idle);
      _showGpsPermissionSheet();
      return;
    }

    // Get position
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      if (!mounted) return;

      // Build SMS body
      final name =
          ref.read(profileNotifierProvider).valueOrNull?.fullName ?? '';
      final lat = position.latitude;
      final lng = position.longitude;
      final accuracy = position.accuracy.round();
      final time = DateFormat.Hm().format(DateTime.now());
      final url = 'https://maps.google.com/?q=$lat,$lng';

      final smsBody = 'profile.medical_info.sos.gps.sms_body'.tr(
        namedArgs: {
          'name': name,
          'url': url,
          'accuracy': accuracy.toString(),
          'time': time,
        },
      );

      // Use primary or first contact phone for SMS target
      String phone = '911'; // fallback
      if (contacts.isNotEmpty) {
        final primary = contacts.firstWhere(
          (c) => c.primary,
          orElse: () => contacts.first,
        );
        phone = _cleanPhone(primary.phone);
      }

      final encodedBody = Uri.encodeQueryComponent(smsBody);
      final smsUri = Uri.parse('sms:$phone?body=$encodedBody');

      setState(() => _gpsState = _GpsState.success);

      // Reset to idle after 2s
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _gpsState = _GpsState.idle);
      });

      await launchUrl(smsUri, mode: LaunchMode.externalApplication);
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _gpsState = _GpsState.error);
    } catch (_) {
      if (!mounted) return;
      setState(() => _gpsState = _GpsState.error);
    }
  }

  void _showGpsPermissionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: MedicoTokens.rose50,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'profile.medical_info.sos.gps.permission_title'.tr(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: MedicoTokens.ink900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'profile.medical_info.sos.gps.permission_body'.tr(),
                  style: const TextStyle(
                    fontSize: 14,
                    color: MedicoTokens.ink600,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MedicoTokens.rose500,
                    foregroundColor: MedicoTokens.paper,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MedicoTokens.rPill),
                    ),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Geolocator.openAppSettings();
                  },
                  child: Text(
                    'profile.medical_info.sos.gps.permission_open_settings'
                        .tr(),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    'profile.medical_info.sos.gps.permission_cancel'.tr(),
                    style: const TextStyle(color: MedicoTokens.ink600),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileNotifierProvider);
    final allergiesAsync = ref.watch(userAllergiesProvider);
    final contactsAsync = ref.watch(emergencyContactsProvider);

    final profile = profileAsync.valueOrNull;
    final allergies = allergiesAsync.valueOrNull ?? [];
    final contacts = contactsAsync.valueOrNull ?? [];

    // Severe allergies only
    final severeAllergies =
        allergies.where((a) => a.severity == AllergySeverity.alta).toList();

    return Scaffold(
      backgroundColor: MedicoTokens.sosCanvas,
      body: SafeArea(
        child: Column(
          children: [
            // ── AppBar 56pt ────────────────────────────────────────────────
            _SosAppBar(onClose: () => Navigator.of(context).maybePop()),

            // ── Scrollable content ─────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  MedicoTokens.s5,
                  MedicoTokens.s4,
                  MedicoTokens.s5,
                  MediaQuery.of(context).padding.bottom + MedicoTokens.s6,
                ),
                children: [
                  // ── Blood hero card ──────────────────────────────────────
                  _BloodHeroCard(profile: profile),
                  const SizedBox(height: 16),

                  // ── Critical allergies strip ─────────────────────────────
                  _AllergyStrip(severeAllergies: severeAllergies),
                  const SizedBox(height: 16),

                  // ── Primary CTA: Call primary contact 88pt ───────────────
                  _PrimaryContactCta(
                    contacts: contacts,
                    onTap: () => _dialPrimary(contacts),
                    isLoading: contactsAsync.isLoading,
                    onGoToProfile: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(height: 12),

                  // ── Secondary CTA: Slide to call 911 72pt ────────────────
                  _Call911Cta(onConfirmed: _dial911),
                  const SizedBox(height: 12),

                  // ── Tertiary CTA: Share GPS location 72pt ─────────────────
                  _GpsCta(
                    gpsState: _gpsState,
                    onTap: () => _shareGpsLocation(contacts),
                  ),
                  const SizedBox(height: 24),

                  // ── Contacts expandable list ─────────────────────────────
                  if (contacts.isNotEmpty)
                    _ContactsList(
                      contacts: contacts,
                      expanded: _contactsExpanded,
                      onToggle: () => setState(
                          () => _contactsExpanded = !_contactsExpanded),
                      onDial: _dial,
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

// ── Sub-widgets ────────────────────────────────────────────────────────────────

/// AppBar personalizado de 56pt con close button + eyebrow + badge "EN VIVO".
class _SosAppBar extends StatefulWidget {
  final VoidCallback onClose;

  const _SosAppBar({required this.onClose});

  @override
  State<_SosAppBar> createState() => _SosAppBarState();
}

class _SosAppBarState extends State<_SosAppBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Semantics(
      label: 'profile.medical_info.sos.title'.tr(),
      header: true,
      child: Container(
        height: 56,
        color: MedicoTokens.sosCritical,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            // Close button 44pt
            Semantics(
              label: 'common.close'.tr(),
              button: true,
              child: GestureDetector(
                onTap: widget.onClose,
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.close_rounded,
                    color: MedicoTokens.sosInkOnCoral,
                    size: 24,
                  ),
                ),
              ),
            ),

            // Eyebrow label — centered
            Expanded(
              child: Text(
                'profile.medical_info.sos.title'.tr(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: MedicoTokens.sosInkOnCoral,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // "EN VIVO" badge with pulsing dot
            Semantics(
              label: 'profile.medical_info.sos.live_badge'.tr(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: MedicoTokens.sosInkOnCoral.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(MedicoTokens.rPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pulsing dot — static if reduce motion
                    if (reduceMotion)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: MedicoTokens.coral300,
                          shape: BoxShape.circle,
                        ),
                      )
                    else
                      AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (_, __) => Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: MedicoTokens.coral300
                                .withValues(alpha: _pulseAnim.value),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    const SizedBox(width: 5),
                    Text(
                      'profile.medical_info.sos.live_badge'.tr(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: MedicoTokens.sosInkOnCoral,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hero card 240pt con tipo de sangre monoespaciado y datos del usuario.
class _BloodHeroCard extends StatelessWidget {
  final UserDetail? profile;

  const _BloodHeroCard({required this.profile});

  int? _computeAge(DateTime? birthDate) {
    if (birthDate == null) return null;
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age < 0 ? 0 : age;
  }

  @override
  Widget build(BuildContext context) {
    final bloodRaw = profile?.blood?.trim();
    final hasBlood = bloodRaw != null && bloodRaw.isNotEmpty;
    // blood is promoted to String (non-null) inside hasBlood-guarded branches
    final blood = bloodRaw ?? '';
    final name = profile?.fullName ?? '';
    final birthDate = profile?.birthDate;
    final age = _computeAge(birthDate);

    // Dynamic type cap for hero glyph
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final glyphSize = (140.0 / textScale).clamp(80.0, 140.0 * 1.15);

    return Semantics(
      label: hasBlood
          ? 'profile.medical_info.sos.hero.blood_label'
              .tr(namedArgs: {'blood': blood})
          : 'profile.medical_info.sos.hero.blood_unknown_label'.tr(),
      child: Container(
        height: 240,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [MedicoTokens.coral500, MedicoTokens.coral600],
          ),
          borderRadius: BorderRadius.circular(MedicoTokens.rHero),
          boxShadow: MedicoTokens.shadowHero,
        ),
        child: Stack(
          children: [
            // Background blob decoration
            Positioned(
              right: -20,
              bottom: -20,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: MedicoTokens.coral700.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Blood glyph — monospace, 140pt
                  Text(
                    hasBlood ? blood : '?',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: glyphSize,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                      letterSpacing: -2.0,
                      color: hasBlood
                          ? MedicoTokens.sosInkOnCoral
                          : MedicoTokens.ink400,
                    ),
                  ),
                  const Spacer(),

                  // Name
                  if (name.isNotEmpty)
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: MedicoTokens.sosInkOnCoral,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                  const SizedBox(height: 4),

                  // Meta: age (only if available) + blood unknown label
                  Row(
                    children: [
                      if (age != null)
                        Text(
                          'profile.medical_info.sos.hero.age_years'.tr(
                            namedArgs: {'age': age.toString()},
                          ),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: MedicoTokens.sosInkOnCoral,
                          ),
                        ),
                      if (!hasBlood) ...[
                        if (age != null) const SizedBox(width: 8),
                        Text(
                          'profile.medical_info.sos.hero.blood_unknown_desc'
                              .tr(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: MedicoTokens.sosInkOnCoral
                                .withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ],
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

/// Strip de alergias severas. Siempre visible — "sin alergias graves" es dato
/// clínico relevante, no ausencia de información.
class _AllergyStrip extends StatelessWidget {
  final List<AllergyModel> severeAllergies;

  const _AllergyStrip({required this.severeAllergies});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'profile.medical_info.sos.critical_allergies_label'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'profile.medical_info.sos.critical_allergies_label'.tr(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: MedicoTokens.ink500,
            ),
          ),
          const SizedBox(height: 8),
          if (severeAllergies.isEmpty)
            Text(
              'profile.medical_info.sos.no_severe_allergies'.tr(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: MedicoTokens.ink500,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: severeAllergies.map((a) {
                return Semantics(
                  label: a.name,
                  child: Container(
                    height: 56,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: MedicoTokens.rose50,
                      borderRadius:
                          BorderRadius.circular(MedicoTokens.rChipSmall),
                      border: Border.all(
                        color: MedicoTokens.roseInk.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        a.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: MedicoTokens.roseInk,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

/// Botón primario 88pt — llamar a contacto principal.
class _PrimaryContactCta extends StatelessWidget {
  final List<EmergencyContactModel> contacts;
  final bool isLoading;
  final VoidCallback onTap;
  final VoidCallback onGoToProfile;

  const _PrimaryContactCta({
    required this.contacts,
    required this.isLoading,
    required this.onTap,
    required this.onGoToProfile,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _ctaShell(
        height: 88,
        child: const CircularProgressIndicator(
          color: MedicoTokens.sosInkOnCoral,
          strokeWidth: 2,
        ),
      );
    }

    // No contacts at all
    if (contacts.isEmpty) {
      return Semantics(
        label: 'profile.medical_info.sos.empty.no_contacts'.tr(),
        button: true,
        child: GestureDetector(
          onTap: onGoToProfile,
          child: _ctaShell(
            height: 88,
            color: MedicoTokens.ink100,
            child: Text(
              'profile.medical_info.sos.empty.no_contacts'.tr(),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: MedicoTokens.ink400,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    // Has contacts
    final primary = contacts.firstWhere(
      (c) => c.primary,
      orElse: () => contacts.first,
    );
    final isPrimary = contacts.any((c) => c.primary);

    final label = isPrimary
        ? 'profile.medical_info.sos.actions.call_primary'.tr(
            namedArgs: {'name': primary.name.toUpperCase()},
          )
        : 'profile.medical_info.sos.actions.call_first_contact'.tr();

    final phoneClean = _cleanPhone(primary.phone);

    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: _ctaShell(
          height: 88,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.phone_rounded,
                    color: MedicoTokens.sosInkOnCoral,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: MedicoTokens.sosInkOnCoral,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              if (phoneClean.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  phoneClean,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: MedicoTokens.sosInkOnCoral.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _cleanPhone(String p) => p.replaceAll(RegExp(r'[^0-9+]'), '');

  Widget _ctaShell({
    required double height,
    required Widget child,
    Color color = MedicoTokens.sosCritical,
  }) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(MedicoTokens.rPill),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: child,
    );
  }
}

/// Botón secundario — slide-to-confirm 911 a 72pt.
class _Call911Cta extends StatelessWidget {
  final VoidCallback onConfirmed;

  const _Call911Cta({required this.onConfirmed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'profile.medical_info.sos.actions.call_911'.tr(),
      button: true,
      child: SlideToConfirmButton(
        label: 'profile.medical_info.sos.actions.call_911'.tr(),
        trackColor: MedicoTokens.ink900,
        thumbColor: MedicoTokens.paper,
        thumbIconColor: MedicoTokens.ink900,
        textColor: MedicoTokens.paper,
        height: 72,
        onConfirmed: onConfirmed,
      ),
    );
  }
}

/// Botón terciario — compartir ubicación por SMS 72pt.
///
/// Implementa estado: idle / acquiring / success / error.
class _GpsCta extends StatelessWidget {
  final _GpsState gpsState;
  final VoidCallback onTap;

  const _GpsCta({required this.gpsState, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;
    Widget? trailing;

    switch (gpsState) {
      case _GpsState.acquiring:
        bg = MedicoTokens.amber50;
        fg = MedicoTokens.amberInk;
        label = 'profile.medical_info.sos.actions.gps_acquiring'.tr();
        trailing = SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: fg,
          ),
        );
        break;
      case _GpsState.success:
        bg = MedicoTokens.mint50;
        fg = MedicoTokens.mintInk;
        label = 'profile.medical_info.sos.actions.gps_sent'.tr();
        trailing = Icon(Icons.check_rounded, color: fg, size: 18);
        break;
      case _GpsState.error:
        bg = MedicoTokens.rose500;
        fg = MedicoTokens.paper;
        label = 'profile.medical_info.sos.actions.gps_failed'.tr();
        trailing = Icon(Icons.refresh_rounded, color: fg, size: 18);
        break;
      case _GpsState.idle:
        bg = MedicoTokens.mint500;
        fg = MedicoTokens.mintInk;
        label = 'profile.medical_info.sos.actions.share_gps'.tr();
        trailing = null;
        break;
    }

    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(MedicoTokens.rPill),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on_rounded, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Lista expandible de contactos.
class _ContactsList extends StatelessWidget {
  final List<EmergencyContactModel> contacts;
  final bool expanded;
  final VoidCallback onToggle;
  final Future<void> Function(String phone) onDial;

  const _ContactsList({
    required this.contacts,
    required this.expanded,
    required this.onToggle,
    required this.onDial,
  });

  @override
  Widget build(BuildContext context) {
    // Always show first contact; rest behind expand
    final extraCount = contacts.length - 1;
    final showAll = expanded || extraCount <= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Text(
          'profile.medical_info.sos.contacts_section_title'.tr(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: MedicoTokens.ink500,
          ),
        ),
        const SizedBox(height: 8),

        // First contact (always visible)
        _ContactTileRow(
          contact: contacts.first,
          onDial: onDial,
        ),

        // "More contacts" toggle
        if (extraCount > 0) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    showAll
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: MedicoTokens.ink500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    showAll
                        ? 'profile.medical_info.sos.contacts_section_title'.tr()
                        : 'profile.medical_info.sos.more_contacts'.tr(
                            namedArgs: {'count': extraCount.toString()},
                          ),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: MedicoTokens.ink500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showAll)
            ...contacts.skip(1).map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _ContactTileRow(contact: c, onDial: onDial),
                  ),
                ),
        ],
      ],
    );
  }
}

/// Tile de un contacto de emergencia — 64pt, tap directo.
class _ContactTileRow extends StatelessWidget {
  final EmergencyContactModel contact;
  final Future<void> Function(String phone) onDial;

  const _ContactTileRow({required this.contact, required this.onDial});

  static String _cleanPhone(String p) => p.replaceAll(RegExp(r'[^0-9+]'), '');

  @override
  Widget build(BuildContext context) {
    final initial = contact.name.isNotEmpty
        ? contact.name.substring(0, 1).toUpperCase()
        : '?';

    return Semantics(
      label: contact.name,
      button: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onDial(_cleanPhone(contact.phone));
        },
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: MedicoTokens.paper,
            borderRadius: BorderRadius.circular(MedicoTokens.rCard),
            boxShadow: MedicoTokens.shadowCard,
          ),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: MedicoTokens.coral100,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: MedicoTokens.coral700,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Name + relationship
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: MedicoTokens.ink900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (contact.relationshipTypeName != null)
                      Text(
                        contact.relationshipTypeName!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: MedicoTokens.ink500,
                        ),
                      ),
                  ],
                ),
              ),

              // Phone icon
              const Icon(
                Icons.phone_rounded,
                color: MedicoTokens.mint500,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
