import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/animations/page_transitions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_dropdown_field.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../../core/widgets/sac_text_field.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../profile/presentation/views/edit_profile_view.dart';
import '../../domain/usecases/redeem_link_code.dart';
import '../family_error_messages.dart';
import '../providers/family_providers.dart';

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
          backgroundColor: AppColors.secondary,
        );
        context.pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final hPad = Responsive.horizontalPadding(context);
    final relationshipTypes = ref.watch(guardianshipRelationshipTypesProvider);
    final error = _error;
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'family.link.intro'.tr(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: c.textSecondary,
                      ),
                ),
                const SizedBox(height: 20),
                SacTextField(
                  controller: _codeController,
                  label: 'family.link.code_label'.tr(),
                  hint: 'family.link.code_hint'.tr(),
                  prefixIcon: HugeIcons.strokeRoundedKey01,
                  textCapitalization: TextCapitalization.characters,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.next,
                  maxLength: 32,
                  onChanged: (_) => setState(() {}),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'family.link.code_required'.tr()
                      : null,
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
                  data: (types) => SacDropdownField<String>(
                    value: _relationshipTypeId,
                    label: 'family.add.relationship'.tr(),
                    hint: 'family.add.relationship_hint'.tr(),
                    prefixIcon: HugeIcons.strokeRoundedUserLove01,
                    items: [
                      for (final type in types)
                        DropdownMenuItem(
                            value: type.id, child: Text(type.name)),
                    ],
                    validator: (v) => v == null
                        ? 'family.add.relationship_required'.tr()
                        : null,
                    onChanged: (v) => setState(() => _relationshipTypeId = v),
                  ),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _swornDeclaration,
                        onChanged: (v) =>
                            setState(() => _swornDeclaration = v ?? false),
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                      ),
                      Expanded(
                        child: Text(
                          'family.link.sworn'.tr(),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: c.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Container(
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
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.error),
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
                const SizedBox(height: 20),
                SacButton.primary(
                  text: 'family.link.submit'.tr(),
                  isLoading: _submitting,
                  onPressed: canSubmit ? _submit : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
