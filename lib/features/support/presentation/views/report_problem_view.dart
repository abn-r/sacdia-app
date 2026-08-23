import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';

import '../../domain/entities/support_category.dart';
import '../../domain/entities/support_report.dart';
import '../providers/support_providers.dart';
import '../widgets/support_chrome.dart';

class ReportProblemView extends ConsumerStatefulWidget {
  const ReportProblemView({super.key});

  static const String routeName = '/settings/support/report';

  @override
  ConsumerState<ReportProblemView> createState() => _ReportProblemViewState();
}

class _ReportProblemViewState extends ConsumerState<ReportProblemView> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  SupportCategory _category = SupportCategory.bug;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(supportReportSubmitProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final deviceInfoAsync = ref.read(deviceReportInfoProvider);
    final deviceInfo = deviceInfoAsync.asData?.value ??
        {
          'platform': 'unknown',
          'osVersion': 'unknown',
          'model': 'unknown',
          'appVersion': 'unknown',
          'buildNumber': 'unknown',
        };

    final draft = SupportReportDraft(
      category: _category,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      deviceInfo: deviceInfo,
      userContext: {
        'locale': context.locale.toString(),
        'route': ReportProblemView.routeName,
      },
    );

    await ref.read(supportReportSubmitProvider.notifier).submit(draft);

    if (!mounted) return;
    final state = ref.read(supportReportSubmitProvider);
    if (state.success != null) {
      _showSuccessDialog();
    } else if (state.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.errorMessage!),
          backgroundColor: context.sac.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSuccessDialog() {
    final scheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: context.sac.barrierColor,
      builder: (ctx) => SacDialog(
        title: 'support.report_success_title'.tr(),
        content: 'support.report_success_body'.tr(),
        icon: HugeIcons.strokeRoundedCheckmarkCircle02,
        iconColor: scheme.secondary,
        iconBackgroundColor: scheme.secondaryContainer,
        actions: [
          SacDialogAction(
            label: 'common.ok'.tr(),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickCategory() async {
    final selected = await showModalBottomSheet<SupportCategory>(
      context: context,
      backgroundColor: context.sac.surface,
      barrierColor: context.sac.barrierColor,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLG),
        ),
      ),
      builder: (ctx) {
        final c = ctx.sac;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  'support.report_pick_category'.tr(),
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        color: c.text,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              for (final category in SupportCategory.values)
                _CategoryOption(
                  category: category,
                  selected: category == _category,
                  onTap: () => Navigator.of(ctx).pop(category),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (selected != null && mounted) {
      setState(() => _category = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final submitState = ref.watch(supportReportSubmitProvider);
    final deviceInfoAsync = ref.watch(deviceReportInfoProvider);
    final c = context.sac;
    final padding = Responsive.horizontalPadding(context);

    return Scaffold(
      backgroundColor: c.background,
      appBar: supportAppBar(context, title: 'support.report_title'.tr()),
      body: AbsorbPointer(
        absorbing: submitState.isSubmitting,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(padding, 8, padding, 24),
                  children: [
                    Text(
                      'support.report_intro'.tr(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: c.textSecondary,
                            height: 1.45,
                          ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'support.report_field_category'.tr(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 6),
                    SacPressable(
                      onTap: _pickCategory,
                      semanticLabel: 'support.report_pick_category'.tr(),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSM),
                          border: Border.all(color: c.border),
                          boxShadow: [
                            BoxShadow(
                              color: c.shadow,
                              offset: const Offset(0, 3),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 15,
                          ),
                          child: Row(
                            children: [
                              HugeIcon(
                                icon: HugeIcons.strokeRoundedFilterHorizontal,
                                color: c.textSecondary,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _category.i18nKey.tr(),
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              HugeIcon(
                                icon: HugeIcons.strokeRoundedArrowDown01,
                                color: c.textTertiary,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SacTextField(
                      controller: _titleCtrl,
                      label: 'support.report_field_title'.tr(),
                      hint: 'support.report_title_hint'.tr(),
                      maxLength: 120,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'support.report_title_required'.tr();
                        }
                        if (v.trim().length < 5) {
                          return 'support.report_title_too_short'.tr();
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    SacTextField(
                      controller: _descCtrl,
                      label: 'support.report_field_description'.tr(),
                      hint: 'support.report_desc_hint'.tr(),
                      maxLength: 2000,
                      maxLines: 6,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'support.report_desc_required'.tr();
                        }
                        if (v.trim().length < 10) {
                          return 'support.report_desc_too_short'.tr();
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.surfaceVariant,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        border: Border.all(color: c.borderLight),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                HugeIcon(
                                  icon:
                                      HugeIcons.strokeRoundedInformationCircle,
                                  color: c.textSecondary,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'support.report_device_info_title'.tr(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: c.text,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            deviceInfoAsync.when(
                              loading: () => Text(
                                'common.loading'.tr(),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: c.textSecondary),
                              ),
                              error: (_, __) => Text(
                                'support.report_device_info_error'.tr(),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: c.error),
                              ),
                              data: (info) => Text(
                                'support.report_device_info'.tr(namedArgs: {
                                  'platform': info['platform']!,
                                  'osVersion': info['osVersion']!,
                                  'model': info['model']!,
                                  'appVersion': info['appVersion']!,
                                  'buildNumber': info['buildNumber']!,
                                }),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: c.textSecondary,
                                      height: 1.4,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _SubmitDock(
                isSubmitting: submitState.isSubmitting,
                onSubmit: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmitDock extends StatelessWidget {
  const _SubmitDock({
    required this.isSubmitting,
    required this.onSubmit,
  });

  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Material(
      color: c.surface,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.border)),
          boxShadow: [
            BoxShadow(
              color: c.shadow,
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          12 + MediaQuery.paddingOf(context).bottom,
        ),
        child: SacButton.primary(
          text: 'support.report_submit'.tr(),
          icon: HugeIcons.strokeRoundedSent02,
          isLoading: isSubmitting,
          isEnabled: !isSubmitting,
          onPressed: onSubmit,
        ),
      ),
    );
  }
}

class _CategoryOption extends StatelessWidget {
  const _CategoryOption({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final SupportCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final scheme = Theme.of(context).colorScheme;
    return SacPressable(
      onTap: onTap,
      semanticLabel: category.i18nKey.tr(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                category.i18nKey.tr(),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: c.text,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
              ),
            ),
            if (selected)
              HugeIcon(
                icon: HugeIcons.strokeRoundedTick02,
                color: scheme.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
