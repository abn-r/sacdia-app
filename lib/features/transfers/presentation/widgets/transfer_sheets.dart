import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_list_row.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_sheet.dart';
import '../../../../core/widgets/sac_text_field.dart';
import '../providers/transfer_providers.dart';

const _sheetShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLG)),
);

/// Max length the server accepts for `reason`.
const transferReasonMaxLength = 500;

/// Summary before sending: what changes, what stays and an optional reason.
/// Resolves to `true` once the request was created.
Future<bool> showTransferConfirmSheet(
  BuildContext context, {
  required String fromClub,
  required String toClub,
  required String keeps,
  required int fromSectionId,
  required int toSectionId,
}) async {
  final sent = await showSacSheet<bool>(
    context: context,
    shape: _sheetShape,
    isScrollControlled: true,
    builder: (_) => _ConfirmSheet(
      fromClub: fromClub,
      toClub: toClub,
      keeps: keeps,
      fromSectionId: fromSectionId,
      toSectionId: toSectionId,
    ),
  );
  return sent ?? false;
}

class _ConfirmSheet extends ConsumerStatefulWidget {
  const _ConfirmSheet({
    required this.fromClub,
    required this.toClub,
    required this.keeps,
    required this.fromSectionId,
    required this.toSectionId,
  });

  final String fromClub;
  final String toClub;
  final String keeps;
  final int fromSectionId;
  final int toSectionId;

  @override
  ConsumerState<_ConfirmSheet> createState() => _ConfirmSheetState();
}

class _ConfirmSheetState extends ConsumerState<_ConfirmSheet> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final reason = _reason.text.trim();
    final ok = await ref.read(createTransferProvider.notifier).create(
          fromSectionId: widget.fromSectionId,
          toSectionId: widget.toSectionId,
          reason: reason.isEmpty ? null : reason,
        );
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final state = ref.watch(createTransferProvider);
    final error = state.errorMessage;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SacSheetHeader(
                title: 'transfers.confirm.title'.tr(namedArgs: {
                  'from': widget.fromClub,
                  'to': widget.toClub,
                }),
                subtitle: 'transfers.confirm.subtitle'
                    .tr(namedArgs: {'club': widget.toClub}),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        border: Border.all(color: c.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'transfers.confirm.keeps'.tr(),
                            style: TextStyle(
                              fontSize: SacFontSize.titleMedium,
                              color: c.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              widget.keeps,
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: SacFontSize.titleMedium,
                                fontWeight: FontWeight.w500,
                                color: c.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SacTextField(
                      key: const ValueKey('transfer-reason'),
                      controller: _reason,
                      label: 'transfers.confirm.reason_label'.tr(),
                      hint: 'transfers.confirm.reason_hint'.tr(),
                      maxLines: 3,
                      maxLength: transferReasonMaxLength,
                      textCapitalization: TextCapitalization.sentences,
                      enabled: !state.isLoading,
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        error,
                        key: const ValueKey('transfer-confirm-error'),
                        style: TextStyle(
                          fontSize: SacFontSize.bodyMedium,
                          color: c.onErrorContainer,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SacButton.primary(
                      key: const ValueKey('transfer-confirm-send'),
                      text: 'transfers.form.submit'.tr(),
                      icon: HugeIcons.strokeRoundedSent,
                      isLoading: state.isLoading,
                      onPressed: state.isLoading ? null : _send,
                    ),
                    const SizedBox(height: 8),
                    SacButton.ghost(
                      text: 'common.cancel'.tr(),
                      onPressed: state.isLoading
                          ? null
                          : () => Navigator.of(context).pop(false),
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

/// One choice in [showTransferPickSheet].
class TransferPickOption {
  const TransferPickOption(this.id, this.name);

  final int id;
  final String name;
}

/// A list to pick one item from (country, union or local field); loads
/// [load] and resolves to the chosen option, or `null` if dismissed.
Future<TransferPickOption?> showTransferPickSheet(
  BuildContext context, {
  required String title,
  required Future<List<TransferPickOption>> Function() load,
}) {
  // Created once: a rebuild of the sheet must not reload the list.
  final future = load();
  return showSacSheet<TransferPickOption>(
    context: context,
    shape: _sheetShape,
    isScrollControlled: true,
    builder: (ctx) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(ctx).height * 0.75,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SacSheetHeader(title: title),
            Flexible(
              child: FutureBuilder<List<TransferPickOption>>(
                future: future,
                builder: (ctx, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: SacLoading()),
                    );
                  }
                  final items = snap.data ?? const <TransferPickOption>[];
                  if (snap.hasError || items.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'transfers.picker.load_error'.tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: ctx.sac.textSecondary),
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
                    itemCount: items.length,
                    itemBuilder: (ctx, i) => SacListRow(
                      leading: const SacListRowIcon(
                        HugeIcons.strokeRoundedLocation01,
                      ),
                      title: items[i].name,
                      onTap: () => Navigator.of(ctx).pop(items[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
