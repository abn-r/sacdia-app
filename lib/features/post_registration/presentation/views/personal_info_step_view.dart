import 'package:flutter/material.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_progress_bar.dart';
import '../providers/personal_info_providers.dart';
import 'emergency_contacts_view.dart';
import 'legal_representative_view.dart';
import 'allergies_selection_view.dart';
import 'diseases_selection_view.dart';

/// Vista del paso 2: Información Personal - Estilo "Scout Vibrante"
///
/// Sin Scaffold interno. Usa SacCard para secciones, chips para género,
/// date pickers limpios. Indicador de progreso de secciones completadas.
/// Title uses responsive font size for small phones.
class PersonalInfoStepView extends ConsumerStatefulWidget {
  const PersonalInfoStepView({super.key});

  @override
  ConsumerState<PersonalInfoStepView> createState() =>
      _PersonalInfoStepViewState();
}

class _PersonalInfoStepViewState extends ConsumerState<PersonalInfoStepView> {
  final _formKey = GlobalKey<FormState>();

  int get _completedSections {
    final formState = ref.read(personalInfoFormProvider);
    final contacts = ref.read(emergencyContactsProvider);
    int count = 0;

    // Section 1: basic data
    if (formState.gender != null && formState.birthdate != null) count++;
    // Section 2: emergency contacts
    if (contacts.hasValue && (contacts.value?.isNotEmpty ?? false)) count++;
    // Section 3: medical info is optional, count if viewed
    final allergies = ref.read(selectedAllergiesProvider);
    final diseases = ref.read(selectedDiseasesProvider);
    if (allergies.isNotEmpty || diseases.isNotEmpty) count++;

    return count;
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(personalInfoFormProvider);
    final contactsAsync = ref.watch(emergencyContactsProvider);
    final legalRepAsync = ref.watch(legalRepresentativeProvider);
    final requiresLegalRepAsync =
        ref.watch(legalRepresentativeRequiredProvider);
    final selectedAllergies = ref.watch(selectedAllergiesProvider);
    final selectedDiseases = ref.watch(selectedDiseasesProvider);
    final canComplete = ref.watch(canCompleteStep2Provider);

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
            'Cuéntanos sobre ti',
            style: titleStyle,
          ),
          const SizedBox(height: 8),
          Text(
            'Esta información ayuda a tu club a cuidarte mejor',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.sac.textSecondary,
                ),
          ),
          const SizedBox(height: 24),

          // Progress indicator
          /*SacProgressBar(
            progress: _completedSections / 3,
            label: '$_completedSections de 3',
            height: 6,
          ),
          const SizedBox(height: 24), */

          // === Section 1: Basic Data ===
          _SectionHeader(
            icon: HugeIcons.strokeRoundedUser,
            title: 'Datos básicos',
            isCompleted:
                formState.gender != null && formState.birthdate != null,
          ),
          const SizedBox(height: 12),

          // Gender chips
          Text(
            'Género',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: context.sac.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _GenderChip(
                label: 'Masculino',
                icon: HugeIcons.strokeRoundedUser,
                isSelected: formState.gender == 'M',
                onTap: () {
                  ref.read(personalInfoFormProvider.notifier).state =
                      formState.copyWith(gender: 'M');
                },
              ),
              const SizedBox(width: 12),
              _GenderChip(
                label: 'Femenino',
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

          // Birthdate
          _DatePickerCard(
            label: 'Fecha de nacimiento',
            icon: HugeIcons.strokeRoundedBirthdayCake,
            date: formState.birthdate,
            onTap: () => _selectBirthdate(context),
          ),
          const SizedBox(height: 16),

          // Baptized toggle
          SacCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SwitchListTile(
              title: const Text(
                '¿Estás bautizado?',
                style: TextStyle(
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
              label: 'Fecha de bautismo',
              icon: HugeIcons.strokeRoundedBlood,
              date: formState.baptismDate,
              onTap: () => _selectBaptismDate(context),
            ),
          ],
          const SizedBox(height: 28),

          // === Section 2: Emergency Contacts ===
          _SectionHeader(
            icon: HugeIcons.strokeRoundedCall02,
            title: 'Contactos de emergencia',
            isCompleted: contactsAsync.hasValue &&
                (contactsAsync.value?.isNotEmpty ?? false),
          ),
          const SizedBox(height: 8),
          Text(
            'Registra al menos un contacto de emergencia',
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
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedContactBook,
                      size: 20,
                      color: contacts.isEmpty
                          ? context.sac.textTertiary
                          : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contacts.isEmpty
                              ? 'Sin contactos registrados'
                              : '${contacts.length} contacto(s)',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (contacts.isEmpty)
                          const Text(
                            'Requerido: al menos 1',
                            style: TextStyle(
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

          // === Legal Representative (conditional) ===
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
                    title: 'Representante legal',
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
                            'Eres menor de 18 años, necesitas registrar un representante legal.',
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
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedUserGroup,
                              size: 20,
                              color: rep != null
                                  ? AppColors.primary
                                  : context.sac.textTertiary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              rep != null
                                  ? rep.fullName
                                  : 'Sin representante registrado',
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

          // === Section 3: Medical Info ===
          _SectionHeader(
            icon: HugeIcons.strokeRoundedFirstAidKit,
            title: 'Información médica',
            subtitle: 'Opcional',
            isCompleted:
                selectedAllergies.isNotEmpty || selectedDiseases.isNotEmpty,
          ),
          const SizedBox(height: 12),

          // Allergies
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
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedBandage,
                    size: 20,
                    color: selectedAllergies.isNotEmpty
                        ? AppColors.error
                        : context.sac.textTertiary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedAllergies.isEmpty
                        ? 'Alergias'
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

          // Diseases
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
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedStethoscope,
                    size: 20,
                    color: selectedDiseases.isNotEmpty
                        ? AppColors.accent
                        : context.sac.textTertiary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedDiseases.isEmpty
                        ? 'Enfermedades'
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
          const SizedBox(height: 24),

          // Warning if incomplete
          if (!canComplete)
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
                      'Completa los campos requeridos para continuar',
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
      helpText: 'Selecciona tu fecha de nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
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
      helpText: 'Selecciona tu fecha de bautismo',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
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
            child: HugeIcon(
                icon: HugeIcons.strokeRoundedTick02,
                size: 14,
                color: Colors.white),
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
                color: isSelected
                    ? AppColors.primary
                    : context.sac.textSecondary,
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
              color: date != null
                  ? AppColors.primary
                  : context.sac.textTertiary,
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
                      : 'Seleccionar fecha',
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
