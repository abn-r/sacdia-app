import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/animations/page_transitions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_legal_consent.dart';
import '../../../../core/widgets/sac_picker_field.dart';
import '../../../../core/widgets/sac_text_field.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../legal/domain/entities/legal_document.dart';
import '../../../legal/presentation/providers/legal_providers.dart';
import '../../../profile/presentation/views/edit_profile_view.dart';
import '../../../post_registration/presentation/widgets/relationship_type_picker_field.dart';
import '../../domain/entities/dependent.dart';
import '../../domain/repositories/family_repository.dart';
import '../family_error_messages.dart';
import '../legal_versions.dart';
import '../providers/family_providers.dart';
import '../widgets/profile_switcher_sheet.dart';

/// Paso 0: alta de un menor sin cuenta (FP-58, FP-59).
///
/// Recoge nombre, apellidos, fecha de nacimiento, parentesco, la declaración
/// bajo protesta y la aceptación de Términos y Privacidad EN NOMBRE del menor
/// (con las versiones que el tutor realmente vio). Al crearlo, la app cambia al
/// perfil del menor y el router lo lleva al post-registro (pasos 1-3).
class AddDependentView extends ConsumerStatefulWidget {
  const AddDependentView({super.key});

  @override
  ConsumerState<AddDependentView> createState() => _AddDependentViewState();
}

class _AddDependentViewState extends ConsumerState<AddDependentView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _paternalController = TextEditingController();
  final _maternalController = TextEditingController();

  DateTime? _birthday;
  String? _relationshipTypeId;
  bool _swornDeclaration = false;
  bool _acceptedLegal = false;
  bool _showBirthdayError = false;
  bool _submitting = false;
  Object? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _paternalController.dispose();
    _maternalController.dispose();
    super.dispose();
  }

  static String? _required(String? value) =>
      (value == null || value.trim().isEmpty)
          ? 'family.add.required'.tr()
          : null;

  static String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      // Se permite un rango amplio: el servidor decide el corte por país y
      // responde GUARDIANSHIP_DEPENDENT_AGE_OUT_OF_RANGE si no corresponde.
      firstDate: DateTime(now.year - 18, now.month, now.day),
      lastDate: now,
      initialDate: _birthday ?? DateTime(now.year - 6, now.month, now.day),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _birthday = picked;
      _showBirthdayError = false;
    });
  }

  Future<void> _submit(LegalSnapshot legal) async {
    final formValid = _formKey.currentState?.validate() ?? false;
    final birthday = _birthday;
    if (birthday == null) setState(() => _showBirthdayError = true);
    final relationshipId = _relationshipTypeId;
    if (!formValid || birthday == null || relationshipId == null) return;
    if (!_swornDeclaration || !_acceptedLegal) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final maternal = _maternalController.text.trim();
    final result = await ref.read(familyActionsProvider).createDependent(
          CreateDependentInput(
            name: _nameController.text.trim(),
            paternalLastName: _paternalController.text.trim(),
            maternalLastName: maternal.isEmpty ? null : maternal,
            birthday: _isoDate(birthday),
            relationshipTypeId: relationshipId,
            swornDeclaration: _swornDeclaration,
            acceptedTermsVersion: legal.termsVersion,
            acceptedPrivacyVersion: legal.privacyVersion,
          ),
        );
    if (!mounted) return;

    final created = result.fold<DependentSummary?>((_) => null, (d) => d);
    if (created == null) {
      final failure = result.fold<Failure?>((f) => f, (_) => null);
      // Las versiones pudieron cambiar mientras se llenaba el formulario:
      // se vuelven a pedir y se pide aceptar de nuevo.
      if (failure?.errorCode == 'LEGAL_VERSION_MISMATCH') {
        ref.invalidate(currentLegalDocumentsProvider);
        _acceptedLegal = false;
      }
      setState(() {
        _submitting = false;
        _error = failure;
      });
      return;
    }

    // Éxito: se actúa por el menor. El router sale de aquí hacia el
    // post-registro en cuanto `/auth/me` del menor carga.
    await switchToDependent(context, ref, created);
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final hPad = Responsive.horizontalPadding(context);
    final relationshipTypes = ref.watch(guardianshipRelationshipTypesProvider);
    final legalAsync = ref.watch(currentLegalDocumentsProvider);
    final legal = legalSnapshotOf(legalAsync.valueOrNull);

    // Si las versiones vigentes cambian, el consentimiento previo ya no vale.
    ref.listen<AsyncValue<List<LegalDocument>>>(currentLegalDocumentsProvider, (
      previous,
      next,
    ) {
      final before = legalSnapshotOf(previous?.valueOrNull);
      final after = legalSnapshotOf(next.valueOrNull);
      if (_acceptedLegal &&
          before != null &&
          after != null &&
          (before.termsVersion != after.termsVersion ||
              before.privacyVersion != after.privacyVersion)) {
        setState(() => _acceptedLegal = false);
      }
    });

    final canSubmit = !_submitting &&
        legal != null &&
        _swornDeclaration &&
        _acceptedLegal &&
        _relationshipTypeId != null &&
        _birthday != null;

    final error = _error;
    final birthdayLabel = _birthday == null
        ? null
        : DateFormat.yMMMMd(context.locale.toString()).format(_birthday!);

    return Scaffold(
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'family.add.title'.tr(),
        backgroundColor: c.background,
        foregroundColor: c.text,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'family.add.intro'.tr(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: c.textSecondary,
                      ),
                ),
                const SizedBox(height: 20),
                SacTextField(
                  controller: _nameController,
                  label: 'family.add.name'.tr(),
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  prefixIcon: HugeIcons.strokeRoundedUser,
                  validator: _required,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                SacTextField(
                  controller: _paternalController,
                  label: 'family.add.paternal'.tr(),
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  validator: _required,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                SacTextField(
                  controller: _maternalController,
                  label: 'family.add.maternal'.tr(),
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                SacPickerField(
                  label: 'family.add.birthday'.tr(),
                  hint: 'family.add.birthday_hint'.tr(),
                  icon: HugeIcons.strokeRoundedCalendar03,
                  selectedName: birthdayLabel,
                  errorText: _showBirthdayError
                      ? 'family.add.birthday_required'.tr()
                      : null,
                  onTap: _pickBirthday,
                ),
                const SizedBox(height: 16),
                relationshipTypes.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => Text(
                    'family.add.relationship_error'.tr(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.error,
                        ),
                  ),
                  data: (types) => RelationshipTypePickerField(
                    selectedId: _relationshipTypeId,
                    relationshipTypes: types,
                    label: 'family.add.relationship'.tr(),
                    placeholder: 'family.add.relationship_hint'.tr(),
                    errorText: 'family.add.relationship_required'.tr(),
                    onSelected: (id) =>
                        setState(() => _relationshipTypeId = id),
                  ),
                ),
                const SizedBox(height: 16),
                _CheckRow(
                  value: _swornDeclaration,
                  label: 'family.add.sworn'.tr(),
                  onChanged: (v) => setState(() => _swornDeclaration = v),
                ),
                if (legal != null)
                  SacLegalConsentCheckbox(
                    value: _acceptedLegal,
                    onChanged: (v) => setState(() => _acceptedLegal = v),
                    termsUrl: legal.termsUrl,
                    privacyUrl: legal.privacyUrl,
                    prefixKey: 'family.add.legal_prefix',
                  )
                else if (!legalAsync.isLoading)
                  _LegalLoadFailed(
                    onRetry: () =>
                        ref.invalidate(currentLegalDocumentsProvider),
                  ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBox(error: error),
                ],
                const SizedBox(height: 20),
                SacButton.primary(
                  text: 'family.add.submit'.tr(),
                  isLoading: _submitting,
                  onPressed: canSubmit ? () => _submit(legal) : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: context.sac.textSecondary,
        );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            materialTapTargetSize: MaterialTapTargetSize.padded,
          ),
          Expanded(child: Text(label, style: style)),
        ],
      ),
    );
  }
}

class _LegalLoadFailed extends StatelessWidget {
  const _LegalLoadFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'family.add.legal_unavailable'.tr(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.error,
                ),
          ),
        ),
        TextButton(onPressed: onRetry, child: Text('common.retry'.tr())),
      ],
    );
  }
}

/// Mensaje de error del servidor y, si el problema es el perfil del propio
/// tutor (menor o sin fecha de nacimiento), el atajo para completarlo.
class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            familyErrorMessage(error),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.error,
                ),
          ),
          if (isGuardianProfileIncomplete(error)) ...[
            const SizedBox(height: 8),
            SacButton.outline(
              text: 'family.add.complete_profile'.tr(),
              icon: HugeIcons.strokeRoundedUserEdit01,
              onPressed: () => Navigator.push(
                context,
                SacSharedAxisRoute(builder: (_) => const EditProfileView()),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
