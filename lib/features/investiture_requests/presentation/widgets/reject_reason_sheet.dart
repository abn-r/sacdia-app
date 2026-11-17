import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_sheet.dart';
import '../../../../core/widgets/sac_text_field.dart';
import '../utils/authorizer_decisions.dart';
import 'investiture_rows.dart';

const _i18n = 'investiture_requests.authorizer.reject_sheet';

/// Abre la hoja del motivo de un rechazo. Devuelve el motivo escrito, o `null`
/// si se cancela (la persona queda sin decidir). La acción real se ejecuta al
/// confirmar la solicitud completa, no aquí.
Future<String?> showRejectReasonSheet(
  BuildContext context, {
  required String personName,
  String? className,
  String? initialReason,
}) {
  return showSacSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => RejectReasonSheet(
      personName: personName,
      className: className,
      initialReason: initialReason,
    ),
  );
}

class RejectReasonSheet extends StatefulWidget {
  const RejectReasonSheet({
    super.key,
    required this.personName,
    this.className,
    this.initialReason,
  });

  final String personName;
  final String? className;
  final String? initialReason;

  @override
  State<RejectReasonSheet> createState() => _RejectReasonSheetState();
}

class _RejectReasonSheetState extends State<RejectReasonSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialReason ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _valid => _controller.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final className = widget.className;

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
              const SacSheetGrabber(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    InvestitureAvatar(name: widget.personName),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(
                              '$_i18n.title',
                              namedArgs: {'name': widget.personName},
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: SacFontSize.titleLarge,
                              fontWeight: FontWeight.w700,
                              color: c.text,
                            ),
                          ),
                          if (className != null && className.isNotEmpty)
                            Text(
                              className,
                              style: TextStyle(
                                fontSize: SacFontSize.bodySmall,
                                color: c.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: SacTextField(
                  key: const ValueKey('reason-field'),
                  controller: _controller,
                  label: tr('$_i18n.reason_label'),
                  helperText: tr('$_i18n.reason_helper'),
                  maxLength: kRejectionReasonMax,
                  maxLines: 4,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: SacButton.outline(
                        text: tr('common.cancel'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: SacButton.primary(
                        text: tr('$_i18n.save'),
                        onPressed: _valid
                            ? () => Navigator.of(context)
                                .pop(_controller.text.trim())
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
