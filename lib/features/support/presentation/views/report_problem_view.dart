import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/support_category.dart';
import '../../domain/entities/support_report.dart';
import '../providers/support_providers.dart';

/// Formulario "Reportar un problema".
///
/// Campos:
/// - Categoría (dropdown enum)
/// - Título (max 120)
/// - Descripción (max 2000)
///
/// El `deviceInfo` se envía automáticamente (transparente al usuario).
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
    // Reseteamos estado previo al entrar — si el usuario envió un reporte,
    // cerró la pantalla y volvió, arrancamos limpio.
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
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSuccessDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const HugeIcon(
          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
          color: Colors.green,
          size: 48,
        ),
        title: Text('support.report_success_title'.tr()),
        content: Text('support.report_success_body'.tr()),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: Text('common.ok'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final submitState = ref.watch(supportReportSubmitProvider);
    final deviceInfoAsync = ref.watch(deviceReportInfoProvider);

    return Scaffold(
      appBar: AppBar(title: Text('support.report_title'.tr())),
      body: AbsorbPointer(
        absorbing: submitState.isSubmitting,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'support.report_intro'.tr(),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),

              // Categoría
              Text('support.report_field_category'.tr(),
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 6),
              DropdownButtonFormField<SupportCategory>(
                initialValue: _category,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  isDense: true,
                ),
                items: SupportCategory.values
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.i18nKey.tr()),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _category = v);
                },
              ),
              const SizedBox(height: 16),

              // Título
              Text('support.report_field_title'.tr(),
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleCtrl,
                maxLength: 120,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'support.report_title_hint'.tr(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
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

              // Descripción
              Text('support.report_field_description'.tr(),
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descCtrl,
                maxLength: 2000,
                maxLines: 6,
                minLines: 4,
                decoration: InputDecoration(
                  hintText: 'support.report_desc_hint'.tr(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
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
              const SizedBox(height: 8),

              // Info del dispositivo (read-only, se envía siempre)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const HugeIcon(
                          icon: HugeIcons.strokeRoundedInformationCircle,
                          color: Colors.blueGrey,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'support.report_device_info_title'.tr(),
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    deviceInfoAsync.when(
                      loading: () => const Text('...'),
                      error: (_, __) =>
                          Text('support.report_device_info_error'.tr()),
                      data: (info) => Text(
                        '${info['platform']} ${info['osVersion']}\n'
                        '${info['model']}\n'
                        'App ${info['appVersion']} (${info['buildNumber']})',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Submit
              FilledButton.icon(
                onPressed: submitState.isSubmitting ? null : _submit,
                icon: submitState.isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const HugeIcon(
                        icon: HugeIcons.strokeRoundedSent02,
                        color: Colors.white,
                        size: 18,
                      ),
                label: Text('support.report_submit'.tr()),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
