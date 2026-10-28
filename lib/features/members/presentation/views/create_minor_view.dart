import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_legal_consent.dart';
import '../../../../core/widgets/sac_picker_field.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../../core/widgets/sac_text_field.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../family/presentation/legal_versions.dart';
import '../../../legal/domain/entities/legal_document.dart';
import '../../../legal/presentation/providers/legal_providers.dart';
import '../../domain/entities/create_minor.dart';
import '../providers/members_providers.dart';
import '../utils/create_minor_errors.dart';
import 'package:sacdia_app/core/widgets/sac_date_picker.dart';

/// Alta de un menor por un director desde una sección del club (FP3-61/64).
///
/// Recoge nombre, apellidos, fecha de nacimiento y género (opcional), la
/// declaración bajo protesta de que el tutor firmó la autorización en papel y la
/// aceptación de Términos y Privacidad EN NOMBRE del menor (con las versiones
/// que el director realmente vio). NO hay correo, usuario ni contraseña: el
/// menor queda sin cuenta, bajo la custodia del club, con una solicitud
/// PENDIENTE que otra persona debe verificar.
///
/// Se hace pop con el [CreatedMinor] cuando el alta se completó.
class CreateMinorView extends ConsumerStatefulWidget {
  const CreateMinorView({super.key, required this.clubSectionId});

  final int clubSectionId;

  @override
  ConsumerState<CreateMinorView> createState() => _CreateMinorViewState();
}

class _CreateMinorViewState extends ConsumerState<CreateMinorView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _paternalController = TextEditingController();
  final _maternalController = TextEditingController();

  DateTime? _birthday;
  String? _gender;
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
          ? 'members.create_minor.required'.tr()
          : null;

  static String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showSacDatePicker(
      context: context,
      // Rango amplio: el servidor decide el corte por país del club y responde
      // GUARDIANSHIP_DEPENDENT_AGE_OUT_OF_RANGE si no corresponde.
      firstDate: DateTime(now.year - 18, now.month, now.day),
      lastDate: now,
      initialDate: _birthday ?? DateTime(now.year - 10, now.month, now.day),
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
    if (!formValid || birthday == null) return;
    if (!_swornDeclaration || !_acceptedLegal) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final maternal = _maternalController.text.trim();
    final result = await ref.read(createMinorUseCaseProvider)(
      CreateMinorInput(
        clubSectionId: widget.clubSectionId,
        name: _nameController.text.trim(),
        paternalLastName: _paternalController.text.trim(),
        maternalLastName: maternal.isEmpty ? null : maternal,
        birthday: _isoDate(birthday),
        gender: _gender,
        swornDeclaration: _swornDeclaration,
        acceptedTermsVersion: legal.termsVersion,
        acceptedPrivacyVersion: legal.privacyVersion,
      ),
    );
    if (!mounted) return;

    final created = result.fold<CreatedMinor?>((_) => null, (m) => m);
    if (created == null) {
      final failure = result.fold<Failure?>((f) => f, (_) => null);
      // Las versiones pudieron cambiar mientras se llenaba el formulario: se
      // vuelven a pedir y hay que aceptar de nuevo.
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

    // Quien registra al menor no puede verificar su consentimiento (cuatro
    // ojos): se recuerda para avisarlo antes de que el servidor responda 403.
    ref.read(createdMinorUserIdsProvider.notifier).update(
          (ids) => {...ids, created.userId},
        );
    // La solicitud pendiente ya existe en el servidor.
    ref.invalidate(membersNotifierProvider);
    SacSnackBar.show(
      context,
      'members.create_minor.created_toast'
          .tr(namedArgs: {'name': created.name}),
    );
    Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final hPad = Responsive.horizontalPadding(context);
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
        _birthday != null;

    final error = _error;
    final birthdayLabel = _birthday == null
        ? null
        : DateFormat.yMMMMd(context.locale.toString()).format(_birthday!);

    return Scaffold(
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'members.create_minor.title'.tr(),
        backgroundColor: c.background,
        foregroundColor: c.text,
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            hPad,
            8,
            hPad,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'members.create_minor.intro'.tr(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: c.textSecondary,
                      ),
                ),
                const SizedBox(height: 20),
                SacTextField(
                  controller: _nameController,
                  label: 'members.create_minor.name'.tr(),
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  prefixIcon: HugeIcons.strokeRoundedUser,
                  validator: _required,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                SacTextField(
                  controller: _paternalController,
                  label: 'members.create_minor.paternal'.tr(),
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  validator: _required,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                SacTextField(
                  controller: _maternalController,
                  label: 'members.create_minor.maternal'.tr(),
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                SacPickerField(
                  label: 'members.create_minor.birthday'.tr(),
                  hint: 'members.create_minor.birthday_hint'.tr(),
                  icon: HugeIcons.strokeRoundedCalendar03,
                  selectedName: birthdayLabel,
                  errorText: _showBirthdayError
                      ? 'members.create_minor.birthday_required'.tr()
                      : null,
                  onTap: _pickBirthday,
                ),
                const SizedBox(height: 16),
                _GenderChoice(
                  value: _gender,
                  enabled: !_submitting,
                  onChanged: (v) => setState(() => _gender = v),
                ),
                const SizedBox(height: 16),
                _CheckRow(
                  value: _swornDeclaration,
                  label: 'members.create_minor.sworn'.tr(),
                  onChanged: (v) => setState(() => _swornDeclaration = v),
                ),
                if (legal != null)
                  SacLegalConsentCheckbox(
                    value: _acceptedLegal,
                    onChanged: (v) => setState(() => _acceptedLegal = v),
                    termsUrl: legal.termsUrl,
                    privacyUrl: legal.privacyUrl,
                    prefixKey: 'members.create_minor.legal_prefix',
                  )
                else if (!legalAsync.isLoading)
                  _LegalLoadFailed(
                    onRetry: () =>
                        ref.invalidate(currentLegalDocumentsProvider),
                  ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBox(message: createMinorErrorMessage(error)),
                ],
                const SizedBox(height: 20),
                SacButton.primary(
                  text: 'members.create_minor.submit'.tr(),
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

/// Género opcional: tocar la opción elegida la deselecciona.
class _GenderChoice extends StatelessWidget {
  const _GenderChoice({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String? value;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    Widget chip(String code, String labelKey) => ChoiceChip(
          label: Text(labelKey.tr()),
          selected: value == code,
          onSelected: enabled ? (on) => onChanged(on ? code : null) : null,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'members.create_minor.gender_label'.tr(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: c.textSecondary,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            chip('M', 'members.create_minor.gender_male'),
            chip('F', 'members.create_minor.gender_female'),
          ],
        ),
      ],
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
            'members.create_minor.legal_unavailable'.tr(),
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

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.error,
            ),
      ),
    );
  }
}
