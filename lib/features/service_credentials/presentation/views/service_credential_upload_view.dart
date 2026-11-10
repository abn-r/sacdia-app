import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/consent/consent_evidence.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/user_error_message.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_notice.dart';
import '../../../../core/widgets/sac_picker_field.dart';
import '../../../../core/widgets/sac_settings.dart';
import '../../../../core/widgets/sac_date_picker.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../domain/entities/service_credential.dart';
import '../providers/service_credentials_providers.dart';
import '../utils/service_credential_form.dart';
import '../utils/service_credential_labels.dart';
import '../widgets/service_credential_document_field.dart';
import '../widgets/service_credential_source_sheet.dart';

/// Upload the counselor credential (the course is the 10 hours): completion
/// date (not in the future) and the file (PDF, JPG or PNG up to 10 MB). Submitting registers, uploads to the signed URL and
/// confirms; a failure keeps the form so the person can retry.
class ServiceCredentialUploadView extends ConsumerStatefulWidget {
  const ServiceCredentialUploadView({
    super.key,
    this.picker = const ConsentEvidencePicker(),
    this.clock = DateTime.now,
  });

  final ConsentEvidencePicker picker;

  /// Injected so tests do not depend on today's date.
  final DateTime Function() clock;

  @override
  ConsumerState<ServiceCredentialUploadView> createState() =>
      _ServiceCredentialUploadViewState();
}

class _ServiceCredentialUploadViewState
    extends ConsumerState<ServiceCredentialUploadView> {
  DateTime? _completedAt;
  ConsentEvidenceLocalFile? _file;
  bool _pickFailed = false;
  bool _showErrors = false;
  Failure? _failure;

  ServiceCredentialFormErrors get _errors => validateServiceCredentialForm(
        completedAt: _completedAt,
        file: _file,
        today: widget.clock(),
      );

  Future<void> _pickDate() async {
    final today = widget.clock();
    final picked = await showSacDatePicker(
      context: context,
      initialDate: _completedAt ?? today,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year, today.month, today.day),
    );
    if (picked == null || !mounted) return;
    setState(() => _completedAt = picked);
  }

  Future<void> _pickFile() async {
    final source = await showServiceCredentialSourceSheet(context);
    if (source == null || !mounted) return;
    try {
      final picked = await widget.picker.pick(source);
      if (picked == null || !mounted) return;
      setState(() {
        _file = picked;
        _pickFailed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _pickFailed = true);
    }
  }

  Future<void> _submit() async {
    final errors = _errors;
    if (!errors.isEmpty) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() => _failure = null);
    final failure =
        await ref.read(serviceCredentialSubmitProvider.notifier).submit(
              draft: ServiceCredentialDraft(completedAt: _completedAt!),
              file: _file!,
            );
    if (!mounted) return;
    if (failure != null) {
      setState(() => _failure = failure);
      return;
    }
    SacSnackBar.show(context, 'service_credentials.upload.success'.tr());
    context.pop();
  }

  String? _dateError(ServiceCredentialDateError? error) => switch (error) {
        ServiceCredentialDateError.required =>
          'service_credentials.upload.date_required'.tr(),
        ServiceCredentialDateError.future =>
          'service_credentials.upload.date_future'.tr(),
        null => null,
      };

  String? _fileError(ServiceCredentialFormErrors errors) {
    if (errors.fileMissing) {
      return 'service_credentials.upload.file_required'.tr();
    }
    if (errors.file != null) {
      return serviceCredentialFileProblemText(errors.file!);
    }
    if (_pickFailed) return 'service_credentials.upload.pick_failed'.tr();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final submit = ref.watch(serviceCredentialSubmitProvider);
    final errors = _showErrors ? _errors : const ServiceCredentialFormErrors();
    final busy = submit.isBusy;
    final failure = _failure;
    final completedAt = _completedAt;

    return Scaffold(
      backgroundColor: c.background,
      appBar: SacTopBar(title: 'service_credentials.upload.title'.tr()),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Text(
                  'service_credentials.upload.intro'.tr(),
                  style: TextStyle(
                    fontSize: SacFontSize.bodyMedium,
                    color: c.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 24),
                SacPickerField(
                  label: 'service_credentials.upload.date_label'.tr(),
                  hint: 'service_credentials.upload.date_hint'.tr(),
                  icon: HugeIcons.strokeRoundedCalendar01,
                  selectedName: completedAt == null
                      ? null
                      : DateFormat('d MMM yyyy', context.locale.toString())
                          .format(completedAt.toLocal()),
                  enabled: !busy,
                  onTap: _pickDate,
                  errorText: _dateError(errors.date),
                ),
                const SizedBox(height: 24),
                _Label('service_credentials.upload.file_label'.tr()),
                const SizedBox(height: 8),
                ServiceCredentialDocumentField(
                  file: _file,
                  onPick: busy ? null : _pickFile,
                  errorText: _fileError(errors),
                ),
              ],
            ),
          ),
          SacPinnedActionBar(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (failure != null) ...[
                  SacNotice(
                    key: const ValueKey('submit-error'),
                    tone: SacNoticeTone.error,
                    text: userErrorMessage(failure),
                    liveRegion: true,
                  ),
                  const SizedBox(height: 10),
                ],
                if (busy) ...[
                  _Progress(state: submit),
                  const SizedBox(height: 12),
                ],
                SacButton.primary(
                  text: failure != null
                      ? 'service_credentials.upload.retry'.tr()
                      : 'service_credentials.upload.submit'.tr(),
                  icon: HugeIcons.strokeRoundedUpload01,
                  isLoading: busy,
                  onPressed: busy ? null : _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w600),
      );
}

class _Progress extends StatelessWidget {
  const _Progress({required this.state});

  final ServiceCredentialSubmitState state;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final uploading = state.phase == ServiceCredentialSubmitPhase.uploading;
    final label = switch (state.phase) {
      ServiceCredentialSubmitPhase.uploading =>
        'service_credentials.upload.phase_uploading'.tr(),
      ServiceCredentialSubmitPhase.confirming =>
        'service_credentials.upload.phase_confirming'.tr(),
      _ => 'service_credentials.upload.phase_registering'.tr(),
    };
    return Semantics(
      liveRegion: true,
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusXS),
            child: LinearProgressIndicator(
              value: uploading ? state.progress : null,
              minHeight: 6,
              color: SacAccent.of(context).color,
              backgroundColor: c.borderLight,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: SacFontSize.bodySmall,
              color: c.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
