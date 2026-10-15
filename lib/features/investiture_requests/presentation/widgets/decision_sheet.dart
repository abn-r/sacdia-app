import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../../../core/widgets/sac_sheet.dart';
import '../../../../core/widgets/sac_text_field.dart';
import '../utils/authorizer_decisions.dart';

const _i18n = 'investiture_requests.authorizer.sheet';

/// Abre la hoja para decidir sobre una persona: investir (comentario opcional)
/// o rechazar (motivo obligatorio).
///
/// Devuelve la elección, [ClearChoice] si se quita la decisión tomada, o
/// `null` si se cierra sin cambios. La acción real se ejecuta al confirmar la
/// solicitud completa, no aquí.
Future<DecisionChoice?> showDecisionSheet(
  BuildContext context, {
  required String personName,
  String? className,
  DecisionChoice? current,
}) {
  return showSacSheet<DecisionChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DecisionSheet(
      personName: personName,
      className: className,
      current: current,
    ),
  );
}

enum _Mode { invest, reject }

class DecisionSheet extends StatefulWidget {
  const DecisionSheet({
    super.key,
    required this.personName,
    this.className,
    this.current,
  });

  final String personName;
  final String? className;
  final DecisionChoice? current;

  @override
  State<DecisionSheet> createState() => _DecisionSheetState();
}

class _DecisionSheetState extends State<DecisionSheet> {
  final _commentController = TextEditingController();
  final _reasonController = TextEditingController();
  _Mode? _mode;

  @override
  void initState() {
    super.initState();
    switch (widget.current) {
      case InvestChoice(:final comment):
        _mode = _Mode.invest;
        _commentController.text = comment ?? '';
      case RejectChoice(:final reason):
        _mode = _Mode.reject;
        _reasonController.text = reason;
      case ClearChoice():
      case null:
        break;
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  bool get _valid => switch (_mode) {
        _Mode.invest => true,
        _Mode.reject => _reasonController.text.trim().isNotEmpty,
        null => false,
      };

  void _save() {
    switch (_mode) {
      case _Mode.invest:
        final comment = _commentController.text.trim();
        Navigator.of(context).pop(
          InvestChoice(comment: comment.isEmpty ? null : comment),
        );
      case _Mode.reject:
        Navigator.of(context).pop(
          RejectChoice(reason: _reasonController.text.trim()),
        );
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final theme = Theme.of(context);
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
              SacSheetHeader(
                title: widget.personName,
                subtitle: className == null || className.isEmpty
                    ? tr('$_i18n.title')
                    : '$className · ${tr('$_i18n.title')}',
                showClose: true,
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _OptionTile(
                            label: tr('$_i18n.invest'),
                            icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                            color: AppColors.validatedColor,
                            selected: _mode == _Mode.invest,
                            onTap: () => setState(() => _mode = _Mode.invest),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _OptionTile(
                            label: tr('$_i18n.reject'),
                            icon: HugeIcons.strokeRoundedCancelCircle,
                            color: AppColors.coral700,
                            selected: _mode == _Mode.reject,
                            onTap: () => setState(() => _mode = _Mode.reject),
                          ),
                        ),
                      ],
                    ),
                    if (_mode == _Mode.invest) ...[
                      const SizedBox(height: 16),
                      SacTextField(
                        key: const ValueKey('comment-field'),
                        controller: _commentController,
                        label: tr('$_i18n.comment_label'),
                        helperText: tr('$_i18n.comment_helper'),
                        maxLength: kAuthorizationCommentMax,
                        maxLines: 4,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ] else if (_mode == _Mode.reject) ...[
                      const SizedBox(height: 16),
                      SacTextField(
                        key: const ValueKey('reason-field'),
                        controller: _reasonController,
                        label: tr('$_i18n.reason_label'),
                        helperText: tr('$_i18n.reason_helper'),
                        maxLength: kRejectionReasonMax,
                        maxLines: 4,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) => setState(() {}),
                      ),
                      if (!_valid) ...[
                        const SizedBox(height: 4),
                        Text(
                          tr('$_i18n.reason_required'),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: c.textSecondary),
                        ),
                      ],
                    ],
                    const SizedBox(height: 20),
                    SacButton.primary(
                      text: tr('$_i18n.save'),
                      onPressed: _valid ? _save : null,
                    ),
                    if (widget.current != null &&
                        widget.current is! ClearChoice) ...[
                      const SizedBox(height: 8),
                      SacButton.ghost(
                        text: tr('$_i18n.clear'),
                        onPressed: () =>
                            Navigator.of(context).pop(const ClearChoice()),
                      ),
                    ],
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

/// Opción de decisión grande (objetivo táctil ≥ 52) con ícono y texto: el color
/// nunca es el único indicador del estado elegido.
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final List<List<dynamic>> icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? color.withValues(alpha: 0.12) : c.paper,
        borderRadius: BorderRadius.circular(16),
        child: SacInkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? color : c.ink150,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                HugeIcon(
                    icon: icon, size: 20, color: selected ? color : c.ink500),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: selected ? color : c.ink800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
