import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/animations/page_transitions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/class_tone.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../profile/presentation/views/edit_profile_view.dart';
import '../../../post_registration/presentation/widgets/relationship_type_picker_field.dart';
import '../../domain/usecases/redeem_link_code.dart';
import '../family_error_messages.dart';
import '../providers/family_providers.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

/// Canjear un código de vinculación (segundo tutor o reclamo del director).
///
/// El código se acepta en cualquier mayúscula/minúscula y con o sin guion: se
/// envía tal cual lo escribió la persona y el servidor lo normaliza (FP-62).
/// Todo fallo de código (desconocido, vencido, usado o revocado) muestra UN solo
/// mensaje genérico para no dar pistas.
class RedeemLinkCodeView extends ConsumerStatefulWidget {
  const RedeemLinkCodeView({super.key});

  @override
  ConsumerState<RedeemLinkCodeView> createState() => _RedeemLinkCodeViewState();
}

class _RedeemLinkCodeViewState extends ConsumerState<RedeemLinkCodeView> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  String? _relationshipTypeId;
  bool _swornDeclaration = false;
  bool _submitting = false;
  Object? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final relationshipId = _relationshipTypeId;
    if (relationshipId == null || !_swornDeclaration) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await ref.read(familyActionsProvider).redeemLinkCode(
          RedeemLinkCodeParams(
            code: _codeController.text.trim(),
            relationshipTypeId: relationshipId,
            swornDeclaration: _swornDeclaration,
          ),
        );
    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _submitting = false;
        _error = failure;
      }),
      (dependent) {
        setState(() => _submitting = false);
        SacSnackBar.show(
          context,
          'family.link.success'.tr(namedArgs: {'name': dependent.firstName}),
          isSuccess: true,
        );
        context.pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final theme = Theme.of(context);
    final hPad = Responsive.horizontalPadding(context);
    final relationshipTypes = ref.watch(guardianshipRelationshipTypesProvider);
    final error = _error;
    final accent = SacAccent.of(context);
    final tone = ClassTone.of(context, accent.color);
    final canSubmit = !_submitting &&
        _relationshipTypeId != null &&
        _swornDeclaration &&
        _codeController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'family.link.title'.tr(),
        backgroundColor: c.background,
        foregroundColor: c.text,
      ),
      // The action stays in the thumb zone while the form scrolls.
      bottomNavigationBar: SafeArea(
        minimum: EdgeInsets.fromLTRB(hPad, 8, hPad, 12),
        child: SacButton.primary(
          key: const ValueKey('family-link-submit'),
          text: 'family.link.submit'.tr(),
          isLoading: _submitting,
          onPressed: canSubmit ? _submit : null,
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: tone.container,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                      ),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedKey01,
                        size: 22,
                        color: tone.onContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'family.link.intro'.tr(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _FieldLabel('family.link.code_label'.tr()),
                const SizedBox(height: 8),
                // Big, centered and spaced so a code read from another
                // phone is easy to copy. The server normalizes case and dashes.
                TextFormField(
                  key: const ValueKey('family-link-code'),
                  controller: _codeController,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  keyboardType: TextInputType.visiblePassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  maxLength: 32,
                  onChanged: (_) => setState(() {}),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'family.link.code_required'.tr()
                      : null,
                  style: TextStyle(
                    fontSize: SacFontSize.displaySmall,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 4,
                    color: c.text,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'family.link.code_hint'.tr(),
                    hintStyle: TextStyle(
                      fontSize: SacFontSize.displaySmall,
                      letterSpacing: 4,
                      color: c.textTertiary.withValues(alpha: 0.6),
                    ),
                    filled: true,
                    fillColor: c.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      borderSide: BorderSide(color: c.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      borderSide: BorderSide(color: accent.color, width: 1.5),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      borderSide: BorderSide(color: c.error),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      borderSide: BorderSide(color: c.error, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'family.link.code_helper'.tr(),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: c.textTertiary,
                  ),
                ),
                const SizedBox(height: 20),
                relationshipTypes.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => Text(
                    'family.add.relationship_error'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
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
                const SizedBox(height: 20),
                // The whole card toggles the declaration.
                Material(
                  color: _swornDeclaration ? accent.surface : c.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    side: BorderSide(
                      color: _swornDeclaration ? accent.color : c.border,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: CheckboxListTile(
                    key: const ValueKey('family-link-sworn'),
                    value: _swornDeclaration,
                    onChanged: (v) =>
                        setState(() => _swornDeclaration = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: Text(
                      'family.link.sworn'.tr(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: c.text,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: c.errorContainer,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          familyErrorMessage(error),
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: c.onErrorContainer),
                        ),
                        if (isGuardianProfileIncomplete(error)) ...[
                          const SizedBox(height: 8),
                          SacButton.outline(
                            text: 'family.add.complete_profile'.tr(),
                            icon: HugeIcons.strokeRoundedUserEdit01,
                            onPressed: () => Navigator.push(
                              context,
                              SacSharedAxisRoute(
                                builder: (_) => const EditProfileView(),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.sac.text,
          ),
    );
  }
}
