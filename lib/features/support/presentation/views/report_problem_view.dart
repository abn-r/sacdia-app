import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_frosted_footer.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/sac_value_row.dart';
import 'package:sacdia_app/core/widgets/status_progress/status_progress.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';

import '../../domain/entities/support_category.dart';
import '../../domain/entities/support_report.dart';
import '../providers/support_providers.dart';

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

  /// The report once it was sent: the screen shows it instead of the form.
  SupportReportDraft? _sent;

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
      // The screen turns into the confirmation (see [build]).
      setState(() => _sent = draft);
    } else if (state.errorMessage != null) {
      SacSnackBar.show(context, state.errorMessage!, isError: true);
    }
  }

  Future<void> _pickCategory() async {
    final selected = await showSacSheet<SupportCategory>(
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
    final displayName = ref.watch(deviceDisplayNameProvider).value;
    final c = context.sac;
    final padding = Responsive.horizontalPadding(context);
    final sent = _sent;

    if (sent != null) {
      return Scaffold(
        backgroundColor: c.background,
        appBar: SacTopBar(
          title: 'support.report_title'.tr(),
          backgroundColor: c.background,
          foregroundColor: c.text,
        ),
        body: _SentBody(draft: sent),
        bottomNavigationBar: SacFrostedFooter(
          child: SacButton.primary(
            key: const ValueKey('support-report-done'),
            text: 'support.report_done'.tr(),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(title: 'support.report_title'.tr(), frosted: true),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => AbsorbPointer(
            absorbing: submitState.isSubmitting,
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: SacTopBar.paddingBelowBar(
                          context, const EdgeInsets.fromLTRB(0, 8, 0, 24)),
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: padding),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'support.report_intro'.tr(),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: c.textSecondary,
                                      height: 1.45,
                                    ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'support.report_field_category'.tr(),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              SacPressable(
                                onTap: _pickCategory,
                                semanticLabel:
                                    'support.report_pick_category'.tr(),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: c.surface,
                                    borderRadius: BorderRadius.circular(
                                        AppTheme.radiusSM),
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
                                          icon: HugeIcons
                                              .strokeRoundedFilterHorizontal,
                                          color: c.textSecondary,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _category.i18nKey.tr(),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium,
                                          ),
                                        ),
                                        HugeIcon(
                                          icon: HugeIcons
                                              .strokeRoundedArrowDown01,
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
                                    return 'support.report_title_too_short'
                                        .tr();
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
                            ],
                          ),
                        ),
                        SacGroupedSection(
                          label: 'support.report_device_group'.tr(),
                          action: const SizedBox.shrink(),
                          dividerIndent: 16,
                          children: [
                            deviceInfoAsync.when(
                              loading: () => SacValueRow(
                                label: 'support.report_device_system'.tr(),
                                value: 'common.loading'.tr(),
                              ),
                              error: (_, __) => Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  'support.report_device_info_error'.tr(),
                                  style: TextStyle(color: c.error),
                                ),
                              ),
                              data: (info) => _DeviceRows(
                                info: info,
                                displayName: displayName,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SacFrostedFooter(
        child: SacButton.primary(
          key: const ValueKey('support-report-submit'),
          text: 'support.report_submit'.tr(),
          icon: HugeIcons.strokeRoundedSent02,
          isLoading: submitState.isSubmitting,
          isEnabled: !submitState.isSubmitting,
          onPressed: _submit,
        ),
      ),
    );
  }
}

/// System, phone and app version, with readable names.
class _DeviceRows extends StatelessWidget {
  const _DeviceRows({required this.info, required this.displayName});

  final Map<String, dynamic> info;
  final String? displayName;

  @override
  Widget build(BuildContext context) {
    final platform = '${info['platform']}';
    final os = '${info['osVersion']}';
    final system = switch (platform) {
      'ios' => 'iOS $os',
      'macos' => 'macOS $os',
      _ => os,
    };
    return Column(
      children: [
        SacValueRow(label: 'support.report_device_system'.tr(), value: system),
        Divider(
          height: 1,
          thickness: 1,
          indent: 16,
          color: context.sac.divider,
        ),
        SacValueRow(
          label: 'support.report_device_model'.tr(),
          value: displayName ?? '${info['model']}',
        ),
        Divider(
          height: 1,
          thickness: 1,
          indent: 16,
          color: context.sac.divider,
        ),
        SacValueRow(
          label: 'support.report_device_app'.tr(),
          value: '${info['appVersion']} (${info['buildNumber']})',
        ),
      ],
    );
  }
}

/// After sending: what was sent, and one way out.
class _SentBody extends StatelessWidget {
  const _SentBody({required this.draft});

  final SupportReportDraft draft;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: SacStatePanel(
            key: const ValueKey('support-report-sent'),
            style: SacStatusStyle.of(
              context,
              SacStatusKind.validated,
              label: 'support.report_success_title'.tr(),
            ),
            title: 'support.report_success_title'.tr(),
            message: 'support.report_success_body'.tr(),
          ),
        ),
        SacGroupedSection(
          label: 'support.report_sent_group'.tr(),
          action: const SizedBox.shrink(),
          dividerIndent: 16,
          children: [
            SacValueRow(
              label: 'support.report_field_category'.tr(),
              value: draft.category.i18nKey.tr(),
            ),
            SacValueRow(
              label: 'support.report_field_title'.tr(),
              value: draft.title,
            ),
          ],
        ),
      ],
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
