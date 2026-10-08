import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_empty_state.dart';
import '../../../../core/widgets/sac_top_bar.dart';

/// Estado a pantalla completa (acceso, sin datos, error) para las pantallas de
/// investidura con barra superior translúcida, con reintento opcional vía
/// [onRetry].
class InvestitureMessageState extends StatelessWidget {
  const InvestitureMessageState({
    super.key,
    required this.title,
    this.body,
    this.icon = HugeIcons.strokeRoundedAlert02,
    this.onRetry,
  });

  final String title;
  final String? body;
  final List<List<dynamic>> icon;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: SacTopBar.frostedInset(context)),
      child: SacEmptyState(
        title: title,
        body: body,
        icon: icon,
        actionLabel: onRetry == null ? null : tr('common.retry'),
        onAction: onRetry,
        actionIcon: HugeIcons.strokeRoundedRefresh,
        actionVariant: SacButtonVariant.outline,
      ),
    );
  }
}
