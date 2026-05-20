import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/secure_screen.dart';
import 'package:sacdia_app/features/post_registration/data/models/allergy_model.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/personal_info_providers.dart';
import 'package:sacdia_app/features/post_registration/presentation/views/allergies_selection_view.dart';
import 'package:sacdia_app/features/post_registration/presentation/views/diseases_selection_view.dart';
import 'package:sacdia_app/features/post_registration/presentation/views/medicines_selection_view.dart';
import 'package:sacdia_app/features/post_registration/presentation/views/emergency_contacts_view.dart';
import 'package:sacdia_app/features/post_registration/presentation/views/legal_representative_view.dart';
import 'package:sacdia_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:sacdia_app/features/profile/presentation/widgets/blood_type_selector.dart';
import 'package:sacdia_app/features/virtual_card/presentation/providers/virtual_card_providers.dart';

import '../widgets/medico/medico_tokens.dart';
import '../widgets/medico/blood_hero_card.dart';
import '../widgets/medico/medico_section_card.dart';
import '../widgets/medico/medical_chip.dart';
import '../widgets/medico/contact_tile.dart';
import '../widgets/medico/medicament_tile.dart';
import '../widgets/medico/empty_hint.dart';

/// Mapea [AllergySeverity] a [SeverityTone] para renderizar chips.
SeverityTone _severityTone(AllergySeverity severity) => switch (severity) {
      AllergySeverity.alta => SeverityTone.rose,
      AllergySeverity.media => SeverityTone.amber,
      AllergySeverity.leve => SeverityTone.mint,
    };

class MedicalInfoView extends ConsumerWidget {
  const MedicalInfoView({super.key});

  // ── Helpers para url_launcher ──────────────────────────────────────────────

  static String _cleanPhone(String p) => p.replaceAll(RegExp(r'[^0-9+]'), '');

  static Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:${_cleanPhone(phone)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> _sms(String phone) async {
    final uri = Uri.parse('sms:${_cleanPhone(phone)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Selector de tipo de sangre ─────────────────────────────────────────────

  Future<void> _handleEditBlood(
    BuildContext context,
    WidgetRef ref,
    String? currentBlood,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final selected = await showBloodTypeSelector(
      context,
      current: BloodType.fromDisplay(currentBlood),
    );
    if (selected == null) return;

    final ok = await ref.read(profileNotifierProvider.notifier).updateProfile({
      'blood': selected.apiKey,
    });

    if (ok) {
      ref.invalidate(virtualCardFetcherProvider);
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'profile.medical_info.blood_type_updated'.tr(
                  namedArgs: {'value': selected.display},
                )
              : 'profile.medical_info.blood_type_update_failed'.tr(),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? null : AppColors.error,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allergiesAsync = ref.watch(userAllergiesProvider);
    final diseasesAsync = ref.watch(userDiseasesProvider);
    final medicinesAsync = ref.watch(userMedicinesProvider);
    final contactsAsync = ref.watch(emergencyContactsProvider);
    final legalRepAsync = ref.watch(legalRepresentativeProvider);
    final legalRequiredAsync = ref.watch(legalRepresentativeRequiredProvider);
    final profileAsync = ref.watch(profileNotifierProvider);

    // Extraer datos crudos para calcular la completitud
    final blood = profileAsync.valueOrNull?.blood?.trim();
    final allergies = allergiesAsync.valueOrNull ?? [];
    final diseases = diseasesAsync.valueOrNull ?? [];
    final medicines = medicinesAsync.valueOrNull ?? [];
    final contacts = contactsAsync.valueOrNull ?? [];

    // Calcular completitud: 5 secciones posibles
    int filled = 0;
    if (blood != null && blood.isNotEmpty) filled++;
    if (allergies.isNotEmpty) filled++;
    if (diseases.isNotEmpty) filled++;
    if (medicines.isNotEmpty) filled++;
    if (contacts.isNotEmpty) filled++;
    const total = 5;

    return SecureScreen(
      child: Scaffold(
        backgroundColor: MedicoTokens.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _MedicoAppBar(
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    MediaQuery.of(context).padding.bottom + 24,
                  ),
                  children: [
                    // ── Hero: tipo de sangre ────────────────────────────────
                    BloodHeroCard(
                      bloodType:
                          (blood == null || blood.isEmpty) ? null : blood,
                      filled: filled,
                      total: total,
                      onEditar: () => _handleEditBlood(
                        context,
                        ref,
                        profileAsync.valueOrNull?.blood,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Contactos de emergencia ─────────────────────────────
                    MedicoSectionCard(
                      icon: HugeIcons.strokeRoundedContactBook,
                      iconBg: MedicoTokens.coral100,
                      iconFg: MedicoTokens.coral600,
                      title: 'profile.medical_info.emergency_contacts'.tr(),
                      actionLabel: 'profile.medical_info.action_manage'.tr(),
                      onAction: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const EmergencyContactsView(),
                        ),
                      ),
                      child: contactsAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: SacLoadingSmall(),
                        ),
                        error: (e, _) => _SectionError(
                          message: e.toString(),
                          onRetry: () =>
                              ref.invalidate(emergencyContactsProvider),
                        ),
                        data: (contactList) {
                          if (contactList.isEmpty) {
                            return EmptyHint(
                              label: 'profile.medical_info.none_contacts'.tr(),
                              actionLabel:
                                  'profile.medical_info.empty.add_contact_cta'
                                      .tr(),
                              onAction: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const EmergencyContactsView(),
                                ),
                              ),
                            );
                          }
                          return Column(
                            children: [
                              for (var i = 0; i < contactList.length; i++) ...[
                                if (i > 0) const SizedBox(height: 10),
                                ContactTile(
                                  contact: contactList[i],
                                  onCall: (phone) => _call(phone),
                                  onSms: (phone) => _sms(phone),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Alergias ────────────────────────────────────────────
                    MedicoSectionCard(
                      icon: HugeIcons.strokeRoundedFirstAidKit,
                      iconBg: MedicoTokens.rose50,
                      iconFg: MedicoTokens.rose500,
                      title: 'profile.medical_info.allergies'.tr(),
                      actionLabel: 'profile.medical_info.action_edit'.tr(),
                      onAction: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AllergiesSelectionView(),
                        ),
                      ),
                      child: allergiesAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: SacLoadingSmall(),
                        ),
                        error: (e, _) => _SectionError(
                          message: e.toString(),
                          onRetry: () => ref.invalidate(userAllergiesProvider),
                        ),
                        data: (allergyList) {
                          if (allergyList.isEmpty) {
                            return EmptyHint(
                              label: 'profile.medical_info.none_allergies'.tr(),
                              actionLabel:
                                  'profile.medical_info.action_edit'.tr(),
                              onAction: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const AllergiesSelectionView(),
                                ),
                              ),
                            );
                          }
                          return MedicalChipRow(
                            children: allergyList
                                .map((a) => MedicalChip(
                                      label: a.name,
                                      sub: a.severity.i18nKey.tr(),
                                      tone: _severityTone(a.severity),
                                    ))
                                .toList(),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Enfermedades ────────────────────────────────────────
                    MedicoSectionCard(
                      icon: HugeIcons.strokeRoundedHealth,
                      iconBg: MedicoTokens.amber50,
                      iconFg: MedicoTokens.amber500,
                      title: 'profile.medical_info.diseases'.tr(),
                      actionLabel: 'profile.medical_info.action_edit'.tr(),
                      onAction: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DiseasesSelectionView(),
                        ),
                      ),
                      child: diseasesAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: SacLoadingSmall(),
                        ),
                        error: (e, _) => _SectionError(
                          message: e.toString(),
                          onRetry: () => ref.invalidate(userDiseasesProvider),
                        ),
                        data: (diseaseList) {
                          if (diseaseList.isEmpty) {
                            return EmptyHint(
                              label: 'profile.medical_info.none_diseases'.tr(),
                              actionLabel:
                                  'profile.medical_info.action_edit'.tr(),
                              onAction: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const DiseasesSelectionView(),
                                ),
                              ),
                            );
                          }
                          return MedicalChipRow(
                            children: diseaseList.map((d) {
                              final year = d.sinceYear;
                              return MedicalChip(
                                label: d.name,
                                sub: year != null ? 'desde $year' : null,
                                tone: SeverityTone.amber,
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Medicamentos ────────────────────────────────────────
                    MedicoSectionCard(
                      icon: HugeIcons.strokeRoundedMedicine01,
                      iconBg: MedicoTokens.mint50,
                      iconFg: MedicoTokens.mint500,
                      title: 'profile.medical_info.medicines'.tr(),
                      actionLabel: 'profile.medical_info.action_edit'.tr(),
                      onAction: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MedicinesSelectionView(),
                        ),
                      ),
                      child: medicinesAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: SacLoadingSmall(),
                        ),
                        error: (e, _) => _SectionError(
                          message: e.toString(),
                          onRetry: () => ref.invalidate(userMedicinesProvider),
                        ),
                        data: (medicineList) {
                          if (medicineList.isEmpty) {
                            return EmptyHint(
                              label: 'profile.medical_info.none_medicines'.tr(),
                              actionLabel:
                                  'profile.medical_info.action_edit'.tr(),
                              onAction: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const MedicinesSelectionView(),
                                ),
                              ),
                            );
                          }
                          return Column(
                            children: [
                              for (var i = 0; i < medicineList.length; i++) ...[
                                if (i > 0) const SizedBox(height: 8),
                                MedicamentTile(medicine: medicineList[i]),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Representante Legal (condicional) ───────────────────
                    legalRequiredAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (isRequired) {
                        if (!isRequired) return const SizedBox.shrink();
                        return MedicoSectionCard(
                          icon: HugeIcons.strokeRoundedSecurityCheck,
                          iconBg: MedicoTokens.lavender100,
                          iconFg: MedicoTokens.lavender500,
                          title: 'profile.medical_info.legal_rep'.tr(),
                          actionLabel: 'profile.medical_info.action_edit'.tr(),
                          onAction: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LegalRepresentativeView(),
                            ),
                          ),
                          child: legalRepAsync.when(
                            loading: () => const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: SacLoadingSmall(),
                            ),
                            error: (e, _) => _SectionError(
                              message: e.toString(),
                              onRetry: () =>
                                  ref.invalidate(legalRepresentativeProvider),
                            ),
                            data: (rep) {
                              if (rep == null) {
                                return EmptyHint(
                                  label: 'profile.medical_info.not_registered'
                                      .tr(),
                                );
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${rep.name} ${rep.paternalSurname} ${rep.maternalSurname}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: MedicoTokens.ink900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${rep.type} · ${rep.phone}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: MedicoTokens.ink500,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        );
                      },
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

// ─────────── App bar ───────────────────────────────────────────────────────────

class _MedicoAppBar extends StatelessWidget {
  final VoidCallback? onBack;

  const _MedicoAppBar({this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: MedicoTokens.paper,
        border: Border(bottom: BorderSide(color: MedicoTokens.ink150)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
      child: Row(
        children: [
          _circleBtn(
            color: MedicoTokens.ink100,
            iconColor: MedicoTokens.ink800,
            icon: HugeIcons.strokeRoundedArrowLeft01,
            onTap: onBack,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'profile.medical_info.appbar.eyebrow'.tr(),
                  style: const TextStyle(
                    fontSize: 11,
                    color: MedicoTokens.ink400,
                    letterSpacing: 1.32,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'profile.medical_info.title'.tr(),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: MedicoTokens.ink900,
                    letterSpacing: -0.17,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleBtn({
    required Color color,
    required Color iconColor,
    required List<List<dynamic>> icon,
    VoidCallback? onTap,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 38,
          height: 38,
          child: HugeIcon(icon: icon, color: iconColor, size: 22),
        ),
      ),
    );
  }

}

// ─────────── Error inline ──────────────────────────────────────────────────────

class _SectionError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _SectionError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedAlert02,
          size: 16,
          color: AppColors.error,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'profile.medical_info.load_error'.tr(),
            style: const TextStyle(fontSize: 13, color: AppColors.error),
          ),
        ),
        TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'common.retry'.tr(),
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}
