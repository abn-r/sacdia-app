import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import '../providers/personal_info_providers.dart';
import 'emergency_contacts_view.dart';
import 'legal_representative_view.dart';
import 'allergies_selection_view.dart';
import 'diseases_selection_view.dart';
import 'medicines_selection_view.dart';

/// Vista del paso 2: Información Personal - Estilo "Scout Vibrante"
///
/// Sin Scaffold interno. Usa SacCard para secciones, chips para género,
/// date pickers limpios. Indicador de progreso de secciones completadas.
/// Title uses responsive font size for small phones.
class PersonalInfoStepView extends ConsumerStatefulWidget {
  const PersonalInfoStepView({
    super.key,
    required this.canReadSensitiveData,
    required this.canManageAdministrativeCompletion,
    required this.targetUserId,
  });

  final bool canReadSensitiveData;
  final bool canManageAdministrativeCompletion;
  final String targetUserId;

  @override
  ConsumerState<PersonalInfoStepView> createState() =>
      _PersonalInfoStepViewState();
}

class _PersonalInfoStepViewState extends ConsumerState<PersonalInfoStepView> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authNotifierProvider).valueOrNull;
    final formState = ref.watch(personalInfoFormProvider);
    final contactsAsync = ref.watch(emergencyContactsProvider);
    final legalRepAsync = ref.watch(legalRepresentativeProvider);
    final requiresLegalRepAsync =
        ref.watch(legalRepresentativeRequiredProvider);
    final selectedAllergies = ref.watch(selectedAllergiesProvider);
    final selectedDiseases = ref.watch(selectedDiseasesProvider);
    final selectedMedicines = ref.watch(selectedMedicinesProvider);
    final canComplete = ref.watch(canCompleteStep2Provider);
    final canReadEmergencyContacts = canReadSensitiveUserFamilyForUser(
      authUser,
      targetUserId: widget.targetUserId,
      family: SensitiveUserFamily.emergencyContacts,
    );
    final canReadLegalRepresentative = canReadSensitiveUserFamilyForUser(
      authUser,
      targetUserId: widget.targetUserId,
      family: SensitiveUserFamily.legalRepresentative,
    );
    final canReadHealth = canReadSensitiveUserFamilyForUser(
      authUser,
      targetUserId: widget.targetUserId,
      family: SensitiveUserFamily.health,
    );

    // Responsive title style — smaller on very small phones
    final titleStyle = Responsive.isSmallPhone(context)
        ? Theme.of(context).textTheme.headlineLarge
        : Theme.of(context).textTheme.displayMedium;

    final hPad = Responsive.horizontalPadding(context);

    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.symmetric(horizontal: hPad),
        children: [
          const SizedBox(height: 8),

          // Title
          Text(
            tr('post_registration.personal_info.title'),
            style: titleStyle,
          ),
          const SizedBox(height: 8),
          Text(
            tr('post_registration.personal_info.subtitle'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.sac.textSecondary,
                ),
          ),
          const SizedBox(height: 24),

          if (!widget.canReadSensitiveData &&
              widget.canManageAdministrativeCompletion) ...[
            SacCard(
              backgroundColor: AppColors.accentLight,
              borderColor: AppColors.accent.withValues(alpha: 0.3),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedInformationCircle,
                    size: 18,
                    color: AppColors.accentDark,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('post_registration.personal_info.admin_restricted_notice'),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.accentDark,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Progress indicator
          /*SacProgressBar(
            progress: _completedSections / 3,
            label: '$_completedSections de 3',
            height: 6,
          ),
          const SizedBox(height: 24), */

          if (widget.canReadSensitiveData) ...[
            // === Section 1: Basic Data ===
            _SectionHeader(
              icon: HugeIcons.strokeRoundedUser,
              title: tr('post_registration.personal_info.basic_data.section_title'),
              isCompleted:
                  formState.gender != null && formState.birthdate != null,
            ),
            const SizedBox(height: 12),
            Text(
              tr('post_registration.personal_info.gender.label'),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: context.sac.textSecondary,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _GenderChip(
                  label: tr('post_registration.personal_info.gender.male'),
                  icon: HugeIcons.strokeRoundedUser,
                  isSelected: formState.gender == 'M',
                  onTap: () {
                    ref.read(personalInfoFormProvider.notifier).state =
                        formState.copyWith(gender: 'M');
                  },
                ),
                const SizedBox(width: 12),
                _GenderChip(
                  label: tr('post_registration.personal_info.gender.female'),
                  icon: HugeIcons.strokeRoundedUser,
                  isSelected: formState.gender == 'F',
                  onTap: () {
                    ref.read(personalInfoFormProvider.notifier).state =
                        formState.copyWith(gender: 'F');
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            _DatePickerCard(
              label: tr('post_registration.personal_info.birth.label'),
              icon: HugeIcons.strokeRoundedBirthdayCake,
              date: formState.birthdate,
              onTap: () => _selectBirthdate(context),
            ),
            const SizedBox(height: 16),
            SacCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SwitchListTile(
                title: Text(
                  tr('post_registration.personal_info.baptism.toggle_label'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                value: formState.baptized,
                activeTrackColor: AppColors.primaryLight,
                thumbColor: WidgetStatePropertyAll(AppColors.primary),
                contentPadding: EdgeInsets.zero,
                onChanged: (value) {
                  ref.read(personalInfoFormProvider.notifier).state =
                      formState.copyWith(
                    baptized: value,
                    baptismDate: value ? formState.baptismDate : null,
                  );
                },
              ),
            ),
            if (formState.baptized) ...[
              const SizedBox(height: 12),
              _DatePickerCard(
                label: tr('post_registration.personal_info.baptism.label'),
                icon: HugeIcons.strokeRoundedBlood,
                date: formState.baptismDate,
                onTap: () => _selectBaptismDate(context),
              ),
            ],
            const SizedBox(height: 28),
          ],

          if (canReadEmergencyContacts) ...[
            // === Section 2: Emergency Contacts ===
            _SectionHeader(
              icon: HugeIcons.strokeRoundedCall02,
              title: tr('post_registration.personal_info.emergency_contacts.section_title'),
              isCompleted: contactsAsync.hasValue &&
                  (contactsAsync.value?.isNotEmpty ?? false),
            ),
            const SizedBox(height: 8),
            Text(
              tr('post_registration.personal_info.emergency_contacts.hint'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.sac.textTertiary,
                  ),
            ),
            const SizedBox(height: 12),
            contactsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: SacLoadingSmall(),
                ),
              ),
              error: (error, _) => _ErrorCard(message: 'Error: $error'),
              data: (contacts) => SacCard(
                onTap: () => _navigateToEmergencyContacts(),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: contacts.isEmpty
                            ? context.sac.surfaceVariant
                            : AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedContactBook,
                          size: 20,
                          color: contacts.isEmpty
                              ? context.sac.textTertiary
                              : AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contacts.isEmpty
                                ? tr('post_registration.personal_info.emergency_contacts.empty')
                                : '${contacts.length} contacto(s)',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (contacts.isEmpty)
                            Text(
                              tr('post_registration.personal_info.emergency_contacts.required_hint'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.accent,
                              ),
                            ),
                        ],
                      ),
                    ),
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowRight01,
                      color: context.sac.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          if (canReadLegalRepresentative)
            requiresLegalRepAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (required) {
                if (!required) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                      icon: HugeIcons.strokeRoundedUserGroup,
                      title: tr('post_registration.personal_info.legal_representative.section_title'),
                      isCompleted:
                          legalRepAsync.hasValue && legalRepAsync.value != null,
                    ),
                    const SizedBox(height: 8),
                    SacCard(
                      backgroundColor: AppColors.accentLight,
                      borderColor: AppColors.accent.withValues(alpha: 0.3),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          HugeIcon(
                              icon: HugeIcons.strokeRoundedInformationCircle,
                              size: 18,
                              color: AppColors.accentDark),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tr('post_registration.personal_info.legal_representative.minor_notice'),
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.accentDark,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    legalRepAsync.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: SacLoadingSmall(),
                        ),
                      ),
                      error: (error, _) => _ErrorCard(message: 'Error: $error'),
                      data: (rep) => SacCard(
                        onTap: () => _navigateToLegalRepresentative(),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: rep != null
                                    ? AppColors.primaryLight
                                    : context.sac.surfaceVariant,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: HugeIcon(
                                  icon: HugeIcons.strokeRoundedUserGroup,
                                  size: 20,
                                  color: rep != null
                                      ? AppColors.primary
                                      : context.sac.textTertiary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                rep != null
                                    ? rep.fullName
                                    : tr('post_registration.personal_info.legal_representative.empty'),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedArrowRight01,
                              color: context.sac.textTertiary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),

          if (canReadHealth) ...[
            // === Section 3: Medical Info ===
            _SectionHeader(
              icon: HugeIcons.strokeRoundedFirstAidKit,
              title: tr('post_registration.personal_info.health.section_title'),
              subtitle: tr('post_registration.personal_info.health.optional'),
              isCompleted:
                  selectedAllergies.isNotEmpty || selectedDiseases.isNotEmpty || selectedMedicines.isNotEmpty,
            ),
            const SizedBox(height: 12),
            SacCard(
              onTap: () => _navigateToAllergiesSelection(),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: selectedAllergies.isNotEmpty
                          ? AppColors.errorLight
                          : context.sac.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedBandage,
                        size: 20,
                        color: selectedAllergies.isNotEmpty
                            ? AppColors.error
                            : context.sac.textTertiary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      selectedAllergies.isEmpty
                          ? tr('post_registration.personal_info.health.allergies_empty')
                          : '${selectedAllergies.length} alergia(s)',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    color: context.sac.textTertiary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SacCard(
              onTap: () => _navigateToDiseasesSelection(),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: selectedDiseases.isNotEmpty
                          ? AppColors.accentLight
                          : context.sac.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedStethoscope,
                        size: 20,
                        color: selectedDiseases.isNotEmpty
                            ? AppColors.accent
                            : context.sac.textTertiary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      selectedDiseases.isEmpty
                          ? tr('post_registration.personal_info.health.diseases_empty')
                          : '${selectedDiseases.length} enfermedad(es)',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    color: context.sac.textTertiary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SacCard(
              onTap: () => _navigateToMedicinesSelection(),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: selectedMedicines.isNotEmpty
                          ? AppColors.secondaryLight
                          : context.sac.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedMedicine01,
                        size: 20,
                        color: selectedMedicines.isNotEmpty
                            ? AppColors.secondary
                            : context.sac.textTertiary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      selectedMedicines.isEmpty
                          ? tr('post_registration.personal_info.health.medicines_empty')
                          : '${selectedMedicines.length} medicamento(s)',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    color: context.sac.textTertiary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Warning if incomplete
          if (widget.canReadSensitiveData && !canComplete)
            SacCard(
              backgroundColor: AppColors.accentLight,
              borderColor: AppColors.accent.withValues(alpha: 0.3),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  HugeIcon(
                      icon: HugeIcons.strokeRoundedAlertCircle,
                      size: 18,
                      color: AppColors.accentDark),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('post_registration.personal_info.validation.complete_required'),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.accentDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _selectBirthdate(BuildContext context) async {
    final now = DateTime.now();
    final minDate = DateTime(now.year - 99, now.month, now.day);
    final maxDate = DateTime(now.year - 3, now.month, now.day);
    final initialDate = ref.read(personalInfoFormProvider).birthdate ?? maxDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: minDate,
      lastDate: maxDate,
      helpText: tr('post_registration.personal_info.birth.date_picker_help'),
      cancelText: tr('post_registration.personal_info.date.cancel'),
      confirmText: tr('post_registration.personal_info.date.confirm'),
    );
    if (picked != null) {
      ref.read(personalInfoFormProvider.notifier).state =
          ref.read(personalInfoFormProvider).copyWith(birthdate: picked);
    }
  }

  Future<void> _selectBaptismDate(BuildContext context) async {
    final birthdate = ref.read(personalInfoFormProvider).birthdate;
    final now = DateTime.now();
    final initialDate = ref.read(personalInfoFormProvider).baptismDate ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: birthdate ?? DateTime(1900),
      lastDate: now,
      helpText: tr('post_registration.personal_info.baptism.date_picker_help'),
      cancelText: tr('post_registration.personal_info.date.cancel'),
      confirmText: tr('post_registration.personal_info.date.confirm'),
    );
    if (picked != null) {
      ref.read(personalInfoFormProvider.notifier).state =
          ref.read(personalInfoFormProvider).copyWith(baptismDate: picked);
    }
  }

  Future<void> _navigateToEmergencyContacts() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const EmergencyContactsView(),
      ),
    );
  }

  Future<void> _navigateToLegalRepresentative() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const LegalRepresentativeView(),
      ),
    );
  }

  Future<void> _navigateToAllergiesSelection() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AllergiesSelectionView(),
      ),
    );
  }

  Future<void> _navigateToDiseasesSelection() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const DiseasesSelectionView(),
      ),
    );
  }

  Future<void> _navigateToMedicinesSelection() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const MedicinesSelectionView(),
      ),
    );
  }
}

/// Header de sección con ícono, título y badge de completado.
class _SectionHeader extends StatelessWidget {
  final dynamic icon;
  final String title;
  final String? subtitle;
  final bool isCompleted;

  const _SectionHeader({
    required this.icon,
    required this.title,
    this.subtitle,
    this.isCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        buildIcon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: 6),
          Text(
            '($subtitle)',
            style: TextStyle(
              fontSize: 13,
              color: context.sac.textTertiary,
            ),
          ),
        ],
        const Spacer(),
        if (isCompleted)
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.secondary,
            ),
            child: Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedTick02,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}

/// Chip selector de género.
class _GenderChip extends StatelessWidget {
  final String label;
  final dynamic icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenderChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight : context.sac.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : context.sac.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              buildIcon(
                icon,
                size: 20,
                color:
                    isSelected ? AppColors.primary : context.sac.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? AppColors.primary
                      : context.sac.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card para seleccionar fecha.
class _DatePickerCard extends StatelessWidget {
  final String label;
  final dynamic icon;
  final DateTime? date;
  final VoidCallback onTap;

  const _DatePickerCard({
    required this.label,
    required this.icon,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SacCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: date != null
                  ? AppColors.primaryLight
                  : context.sac.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: buildIcon(
              icon,
              size: 20,
              color:
                  date != null ? AppColors.primary : context.sac.textTertiary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.sac.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date != null
                      ? DateFormat('yyyy-MM-dd').format(date!)
                      : tr('post_registration.personal_info.birth.select_date'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: date != null
                        ? context.sac.text
                        : context.sac.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          HugeIcon(
            icon: HugeIcons.strokeRoundedCalendar01,
            size: 18,
            color: context.sac.textTertiary,
          ),
        ],
      ),
    );
  }
}

/// Card de error simple.
class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return SacCard(
      backgroundColor: AppColors.errorLight,
      borderColor: AppColors.error.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(12),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.errorDark, fontSize: 13),
      ),
    );
  }
}
