import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/secure_screen.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
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
import 'package:sacdia_app/core/animations/page_transitions.dart';

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

    SacSnackBar.showMessenger(
      messenger,
      ok
          ? 'profile.medical_info.blood_type_updated'.tr(
              namedArgs: {'value': selected.display},
            )
          : 'profile.medical_info.blood_type_update_failed'.tr(),
      isError: !ok,
      duration: const Duration(seconds: 2),
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
    final rawBlood = profileAsync.valueOrNull?.blood?.trim();
    final blood = BloodType.displayFor(rawBlood);
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

    final m = MedicoTokens.of(context);

    return SecureScreen(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: m.canvas,
        appBar: SacTopBar(
          title: 'profile.medical_info.title'.tr(),
          centerTitle: true,
          frosted: true,
        ),
        body: SacFrostedVeil(
          child: Builder(
            builder: (context) {
              final bar = SacTopBar.frostedInset(context);
              return ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  bar + 8,
                  16,
                  MediaQuery.paddingOf(context).bottom + 24,
                ),
                children: [
                  // ── Hero: tipo de sangre ────────────────────────────────
                  BloodHeroCard(
                    bloodType: (blood == null || blood.isEmpty) ? null : blood,
                    filled: filled,
                    total: total,
                    onEditar: () => _handleEditBlood(
                      context,
                      ref,
                      rawBlood,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Contactos de emergencia ─────────────────────────────
                  MedicoSectionCard(
                    icon: HugeIcons.strokeRoundedContactBook,
                    iconBg: m.coralSoft,
                    iconFg: m.coralFg,
                    title: 'profile.medical_info.emergency_contacts'.tr(),
                    actionLabel: 'profile.medical_info.action_manage'.tr(),
                    onAction: () => Navigator.of(context).push(
                      SacSharedAxisRoute(
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
                              SacSharedAxisRoute(
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
                    iconBg: m.roseSoft,
                    iconFg: m.roseFg,
                    title: 'profile.medical_info.allergies'.tr(),
                    actionLabel: 'profile.medical_info.action_edit'.tr(),
                    onAction: () => Navigator.of(context).push(
                      SacSharedAxisRoute(
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
                              SacSharedAxisRoute(
                                builder: (_) => const AllergiesSelectionView(),
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
                    iconBg: m.amberSoft,
                    iconFg: m.amberFg,
                    title: 'profile.medical_info.diseases'.tr(),
                    actionLabel: 'profile.medical_info.action_edit'.tr(),
                    onAction: () => Navigator.of(context).push(
                      SacSharedAxisRoute(
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
                              SacSharedAxisRoute(
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
                    iconBg: m.mintSoft,
                    iconFg: m.mintFg,
                    title: 'profile.medical_info.medicines'.tr(),
                    actionLabel: 'profile.medical_info.action_edit'.tr(),
                    onAction: () => Navigator.of(context).push(
                      SacSharedAxisRoute(
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
                              SacSharedAxisRoute(
                                builder: (_) => const MedicinesSelectionView(),
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
                        iconBg: m.lavenderSoft,
                        iconFg: m.lavenderFg,
                        title: 'profile.medical_info.legal_rep'.tr(),
                        actionLabel: 'profile.medical_info.action_edit'.tr(),
                        onAction: () => Navigator.of(context).push(
                          SacSharedAxisRoute(
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
                                label:
                                    'profile.medical_info.not_registered'.tr(),
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${rep.name} ${rep.paternalSurname} ${rep.maternalSurname}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: m.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${rep.type} · ${rep.phone}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: m.textSecondary,
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
              );
            },
          ),
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
        SacPressable(
          listenOnly: true,
          child: TextButton(
            onPressed: onRetry,
            style: (TextButton.styleFrom(
              foregroundColor: SacAccent.of(context).color,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )).copyWith(enableFeedback: false),
            child: Text(
              'common.retry'.tr(),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}
