import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';

/// End of a paged queue with more pages: asks for the next one as soon as it
/// is built (lists build it lazily, near the viewport) and offers a retry when
/// that page failed.
class SupervisionLoadMoreFooter extends StatefulWidget {
  const SupervisionLoadMoreFooter({
    super.key,
    required this.loading,
    required this.failed,
    required this.errorMessage,
    required this.onLoadMore,
  });

  final bool loading;
  final bool failed;

  /// Already translated; shown above the retry button.
  final String errorMessage;
  final VoidCallback onLoadMore;

  @override
  State<SupervisionLoadMoreFooter> createState() =>
      _SupervisionLoadMoreFooterState();
}

class _SupervisionLoadMoreFooterState extends State<SupervisionLoadMoreFooter> {
  @override
  void initState() {
    super.initState();
    _maybeLoadMore();
  }

  @override
  void didUpdateWidget(covariant SupervisionLoadMoreFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeLoadMore();
  }

  /// A failed page waits for the retry button instead of looping.
  void _maybeLoadMore() {
    if (widget.loading || widget.failed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onLoadMore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    if (widget.failed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(
              widget.errorMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: 4),
            SacButton.ghost(
              text: 'common.retry'.tr(),
              onPressed: widget.onLoadMore,
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: SacAccent.of(context).color,
            semanticsLabel: 'common.loading'.tr(),
          ),
        ),
      ),
    );
  }
}
