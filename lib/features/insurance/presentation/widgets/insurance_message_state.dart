import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/errors/user_error_message.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_empty_state.dart';
import '../../../../core/widgets/sac_top_bar.dart';

/// Full-screen state under the translucent top bar: no cost yet, no access,
/// offline or a failed load.
class InsuranceMessageState extends StatelessWidget {
  const InsuranceMessageState({
    super.key,
    required this.title,
    this.body,
    this.icon = HugeIcons.strokeRoundedAlert02,
    this.onRetry,
    this.actionLabel,
    this.onAction,
  });

  /// A failed load: offline says so and how to retry; anything else shows
  /// the safe message of the error.
  factory InsuranceMessageState.loadError({
    Key? key,
    required Object? error,
    required VoidCallback onRetry,
  }) {
    if (error is ConnectionFailure || error is NetworkFailure) {
      return InsuranceMessageState(
        key: key,
        title: tr('insurance.states.offline_title'),
        body: tr('insurance.states.offline_body'),
        icon: HugeIcons.strokeRoundedWifiOff01,
        onRetry: onRetry,
      );
    }
    return InsuranceMessageState(
      key: key,
      title: tr('insurance.states.error_title'),
      body: userErrorMessage(error),
      onRetry: onRetry,
    );
  }

  final String title;
  final String? body;
  final List<List<dynamic>> icon;
  final VoidCallback? onRetry;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final hasAction = actionLabel != null && onAction != null;
    return Padding(
      padding: EdgeInsets.only(top: SacTopBar.frostedInset(context)),
      child: SacEmptyState(
        title: title,
        body: body,
        icon: icon,
        actionLabel: hasAction
            ? actionLabel
            : (onRetry == null ? null : tr('common.retry')),
        onAction: hasAction ? onAction : onRetry,
        actionIcon: hasAction ? null : HugeIcons.strokeRoundedRefresh,
        actionVariant: SacButtonVariant.outline,
      ),
    );
  }
}
