import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/personal_info_providers.dart';
import 'package:sacdia_app/features/post_registration/presentation/views/allergies_selection_view.dart';
import 'package:sacdia_app/features/post_registration/presentation/views/diseases_selection_view.dart';
import 'package:sacdia_app/features/post_registration/presentation/views/medicines_selection_view.dart';
import 'package:sacdia_app/features/post_registration/presentation/views/emergency_contacts_view.dart';
import 'package:sacdia_app/features/post_registration/presentation/views/legal_representative_view.dart';
import 'package:sacdia_app/core/widgets/secure_screen.dart';
import 'package:sacdia_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:sacdia_app/features/profile/presentation/widgets/blood_type_selector.dart';
import 'package:sacdia_app/features/virtual_card/presentation/providers/virtual_card_providers.dart';

class MedicalInfoView extends ConsumerWidget {
  const MedicalInfoView({super.key});

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

    final ok = await ref
        .read(profileNotifierProvider.notifier)
        .updateProfile({'blood': selected.apiKey});

    if (ok) {
      // Refrescar la credencial digital para que muestre el nuevo tipo
      // de sangre sin requerir pull-to-refresh manual.
      ref.invalidate(virtualCardFetcherProvider);
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'profile.medical_info.blood_type_updated'
                  .tr(namedArgs: {'value': selected.display})
              : 'profile.medical_info.blood_type_update_failed'.tr(),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? null : AppColors.error,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allergiesAsync = ref.watch(userAllergiesProvider);
    final diseasesAsync = ref.watch(userDiseasesProvider);
    final medicinesAsync = ref.watch(userMedicinesProvider);
    final contactsAsync = ref.watch(emergencyContactsProvider);
    final legalRepAsync = ref.watch(legalRepresentativeProvider);
    final legalRequiredAsync = ref.watch(legalRepresentativeRequiredProvider);
    final profileAsync = ref.watch(profileNotifierProvider);

    final c = context.sac;

    return SecureScreen(
      child: Scaffold(
      appBar: AppBar(
        title: Text('profile.medical_info.title'.tr()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Tipo de sangre — sección compacta antes de las alergias.
          _MedicalSectionCard(
            icon: HugeIcons.strokeRoundedBlood,
            title: 'profile.medical_info.blood_type'.tr(),
            iconColor: AppColors.error,
            body: profileAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SacLoadingSmall(),
              ),
              error: (e, _) => _SectionError(
                message: e.toString(),
                onRetry: () =>
                    ref.read(profileNotifierProvider.notifier).refresh(),
              ),
              data: (profile) {
                final blood = profile?.blood?.trim();
                if (blood == null || blood.isEmpty) {
                  return Text(
                    'profile.medical_info.blood_type_unset'.tr(),
                    style: TextStyle(
                      fontSize: 14,
                      color: c.textTertiary,
                      fontStyle: FontStyle.italic,
                    ),
                  );
                }
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    blood,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.errorDark,
                      letterSpacing: 0.4,
                    ),
                  ),
                );
              },
            ),
            actionLabel: 'profile.medical_info.action_edit'.tr(),
            onAction: () => _handleEditBlood(
              context,
              ref,
              profileAsync.valueOrNull?.blood,
            ),
          ),
          const SizedBox(height: 12),
          _MedicalSectionCard(
            icon: HugeIcons.strokeRoundedFirstAidKit,
            title: 'profile.medical_info.allergies'.tr(),
            iconColor: AppColors.error,
            body: allergiesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SacLoadingSmall(),
              ),
              error: (e, _) => _SectionError(
                message: e.toString(),
                onRetry: () => ref.invalidate(userAllergiesProvider),
              ),
              data: (allergies) {
                if (allergies.isEmpty) {
                  return Text(
                    'profile.medical_info.none_allergies'.tr(),
                    style: TextStyle(
                      fontSize: 14,
                      color: c.textTertiary,
                      fontStyle: FontStyle.italic,
                    ),
                  );
                }
                return Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: allergies
                      .map(
                        (a) => Chip(
                          label: Text(
                            a.name,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.errorDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          backgroundColor: AppColors.errorLight,
                          side: BorderSide(
                            color: AppColors.error.withValues(alpha: 0.3),
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            actionLabel: 'profile.medical_info.action_edit'.tr(),
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AllergiesSelectionView(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _MedicalSectionCard(
            icon: HugeIcons.strokeRoundedHealth,
            title: 'profile.medical_info.diseases'.tr(),
            iconColor: AppColors.accent,
            body: diseasesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SacLoadingSmall(),
              ),
              error: (e, _) => _SectionError(
                message: e.toString(),
                onRetry: () => ref.invalidate(userDiseasesProvider),
              ),
              data: (diseases) {
                if (diseases.isEmpty) {
                  return Text(
                    'profile.medical_info.none_diseases'.tr(),
                    style: TextStyle(
                      fontSize: 14,
                      color: c.textTertiary,
                      fontStyle: FontStyle.italic,
                    ),
                  );
                }
                return Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: diseases
                      .map(
                        (d) => Chip(
                          label: Text(
                            d.name,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.accentDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          backgroundColor: AppColors.accentLight,
                          side: BorderSide(
                            color: AppColors.accent.withValues(alpha: 0.3),
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            actionLabel: 'profile.medical_info.action_edit'.tr(),
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const DiseasesSelectionView(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _MedicalSectionCard(
            icon: HugeIcons.strokeRoundedMedicine01,
            title: 'profile.medical_info.medicines'.tr(),
            iconColor: AppColors.secondary,
            body: medicinesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SacLoadingSmall(),
              ),
              error: (e, _) => _SectionError(
                message: e.toString(),
                onRetry: () => ref.invalidate(userMedicinesProvider),
              ),
              data: (medicines) {
                if (medicines.isEmpty) {
                  return Text(
                    'profile.medical_info.none_medicines'.tr(),
                    style: TextStyle(
                      fontSize: 14,
                      color: c.textTertiary,
                      fontStyle: FontStyle.italic,
                    ),
                  );
                }
                return Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: medicines
                      .map(
                        (m) => Chip(
                          label: Text(
                            m.name,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.secondaryDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          backgroundColor: AppColors.secondaryLight,
                          side: BorderSide(
                            color: AppColors.secondary.withValues(alpha: 0.3),
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            actionLabel: 'profile.medical_info.action_edit'.tr(),
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const MedicinesSelectionView(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _MedicalSectionCard(
            icon: HugeIcons.strokeRoundedContactBook,
            title: 'profile.medical_info.emergency_contacts'.tr(),
            iconColor: AppColors.primary,
            body: contactsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SacLoadingSmall(),
              ),
              error: (e, _) => _SectionError(
                message: e.toString(),
                onRetry: () => ref.invalidate(emergencyContactsProvider),
              ),
              data: (contacts) {
                if (contacts.isEmpty) {
                  return Text(
                    'profile.medical_info.none_contacts'.tr(),
                    style: TextStyle(
                      fontSize: 14,
                      color: c.textTertiary,
                      fontStyle: FontStyle.italic,
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: contacts
                      .map(
                        (contact) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: HugeIcon(
                                    icon: HugeIcons.strokeRoundedUser,
                                    color: AppColors.primaryDark,
                                    size: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      contact.name,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: c.text,
                                      ),
                                    ),
                                    Text(
                                      '${contact.relationshipTypeName ?? contact.relationshipTypeId} · ${contact.phone}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: c.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            actionLabel: 'profile.medical_info.action_manage'.tr(),
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const EmergencyContactsView(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          legalRequiredAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (isRequired) {
              if (!isRequired) return const SizedBox.shrink();
              return _MedicalSectionCard(
                icon: HugeIcons.strokeRoundedUserShield01,
                title: 'profile.medical_info.legal_rep'.tr(),
                iconColor: AppColors.secondary,
                body: legalRepAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: SacLoadingSmall(),
                  ),
                  error: (e, _) => _SectionError(
                    message: e.toString(),
                    onRetry: () => ref.invalidate(legalRepresentativeProvider),
                  ),
                  data: (rep) {
                    if (rep == null) {
                      return Text(
                        'profile.medical_info.not_registered'.tr(),
                        style: TextStyle(
                          fontSize: 14,
                          color: c.textTertiary,
                          fontStyle: FontStyle.italic,
                        ),
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
                            color: c.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${rep.type} · ${rep.phone}',
                          style: TextStyle(
                            fontSize: 12,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                actionLabel: 'profile.medical_info.action_edit'.tr(),
                onAction: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const LegalRepresentativeView(),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
      ),
    );
  }
}

class _MedicalSectionCard extends StatelessWidget {
  final HugeIconData icon;
  final String title;
  final Color iconColor;
  final Widget body;
  final String actionLabel;
  final VoidCallback onAction;

  const _MedicalSectionCard({
    required this.icon,
    required this.title,
    required this.iconColor,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: icon,
                      color: iconColor,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    actionLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: c.borderLight),
          Padding(
            padding: const EdgeInsets.all(14),
            child: body,
          ),
        ],
      ),
    );
  }
}

class _SectionError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _SectionError({
    required this.message,
    required this.onRetry,
  });

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
            style: TextStyle(
              fontSize: 13,
              color: AppColors.error,
            ),
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
