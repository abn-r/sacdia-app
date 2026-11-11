import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_date_picker.dart';
import '../../../../core/widgets/sac_sheet.dart';
import '../../../../core/widgets/sac_text_field.dart';
import '../../../activities/presentation/widgets/activity_form_widgets.dart';

/// Server bounds of the rejection reason (`POST .../reject`).
const int kServiceCredentialReasonMin = 5;
const int kServiceCredentialReasonMax = 500;

/// A reason is valid once trimmed text has 5 to 500 characters.
bool isValidRejectionReason(String raw) {
  final length = raw.trim().length;
  return length >= kServiceCredentialReasonMin &&
      length <= kServiceCredentialReasonMax;
}

/// Decision to approve. [expiresAt] is optional: no date = the credential does
/// not expire.
typedef ApproveChoice = ({DateTime? expiresAt});

Future<ApproveChoice?> showApproveCredentialSheet(
  BuildContext context, {
  DateTime Function() clock = DateTime.now,
}) =>
    _show<ApproveChoice>(context, _ApproveSheet(clock: clock));

/// Asks for the rejection reason (required, 5 to 500 characters). Returns the
/// trimmed reason, or `null` when dismissed.
Future<String?> showRejectCredentialSheet(BuildContext context) =>
    _show<String>(context, const _RejectSheet());

Future<T?> _show<T>(BuildContext context, Widget sheet) => showSacSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => sheet,
    );

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLG),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SacSheetHeader(title: title, showClose: true),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApproveSheet extends StatefulWidget {
  const _ApproveSheet({required this.clock});

  final DateTime Function() clock;

  @override
  State<_ApproveSheet> createState() => _ApproveSheetState();
}

class _ApproveSheetState extends State<_ApproveSheet> {
  DateTime? _expiresAt;

  Future<void> _pick() async {
    final today = widget.clock();
    final first = DateTime(today.year, today.month, today.day);
    final picked = await showSacDatePicker(
      context: context,
      initialDate: _expiresAt ?? first,
      firstDate: first,
      lastDate: DateTime(today.year + 30),
    );
    if (picked != null && mounted) setState(() => _expiresAt = picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return _SheetFrame(
      title: 'service_credentials.review.approve_title'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'service_credentials.review.approve_body'.tr(),
            style: TextStyle(
              fontSize: SacFontSize.bodyMedium,
              color: c.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          ActivityDatePickerField(
            label: 'service_credentials.review.expiry_label'.tr(),
            value: _expiresAt,
            enabled: true,
            onTap: _pick,
            onClear: _expiresAt == null
                ? null
                : () => setState(() => _expiresAt = null),
          ),
          const SizedBox(height: 6),
          Text(
            'service_credentials.review.expiry_helper'.tr(),
            style: TextStyle(
              fontSize: SacFontSize.bodySmall,
              color: c.textTertiary,
            ),
          ),
          const SizedBox(height: 20),
          SacButton.primary(
            text: 'service_credentials.review.approve'.tr(),
            icon: HugeIcons.strokeRoundedCheckmarkCircle02,
            onPressed: () => Navigator.of(context)
                .pop<ApproveChoice>((expiresAt: _expiresAt)),
          ),
        ],
      ),
    );
  }
}

class _RejectSheet extends StatefulWidget {
  const _RejectSheet();

  @override
  State<_RejectSheet> createState() => _RejectSheetState();
}

class _RejectSheetState extends State<_RejectSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final valid = isValidRejectionReason(_controller.text);
    final hasText = _controller.text.trim().isNotEmpty;
    return _SheetFrame(
      title: 'service_credentials.review.reject_title'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'service_credentials.review.reject_body'.tr(),
            style: TextStyle(
              fontSize: SacFontSize.bodyMedium,
              color: c.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          SacTextField(
            key: const ValueKey('reject-reason-field'),
            controller: _controller,
            label: 'service_credentials.review.reason_label'.tr(),
            maxLength: kServiceCredentialReasonMax,
            maxLines: 4,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
          ),
          if (!valid) ...[
            const SizedBox(height: 4),
            Semantics(
              liveRegion: hasText,
              child: Text(
                'service_credentials.review.reason_required'.tr(),
                style: TextStyle(
                  fontSize: SacFontSize.bodySmall,
                  color: hasText ? c.error : c.textSecondary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          SacButton.destructive(
            text: 'service_credentials.review.reject'.tr(),
            icon: HugeIcons.strokeRoundedCancelCircle,
            onPressed: valid
                ? () => Navigator.of(context).pop(_controller.text.trim())
                : null,
          ),
        ],
      ),
    );
  }
}
