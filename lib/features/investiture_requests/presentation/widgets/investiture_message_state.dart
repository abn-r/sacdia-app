import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_empty_state.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../utils/investiture_error_message.dart';

/// Estado a pantalla completa (acceso, sin datos, error) para las pantallas de
/// investidura con barra superior translúcida. Con [onRetry] ofrece reintentar;
/// con [actionLabel] y [onAction] ofrece una salida propia (p. ej. ir a «Mi
/// investidura»).
class InvestitureMessageState extends StatelessWidget {
  const InvestitureMessageState({
    super.key,
    required this.title,
    this.body,
    this.icon = HugeIcons.strokeRoundedAlert02,
    this.onRetry,
    this.actionLabel,
    this.onAction,
  });

  /// Error de carga: sin conexión se dice como tal; el resto, con el título
  /// de la pantalla y el mensaje seguro del error.
  factory InvestitureMessageState.loadError({
    Key? key,
    required String title,
    required Object? error,
    required VoidCallback onRetry,
  }) {
    if (isInvestitureOfflineError(error)) {
      return InvestitureMessageState(
        key: key,
        title: tr('investiture_requests.errors.offline_title'),
        body: tr('investiture_requests.errors.offline_body'),
        icon: HugeIcons.strokeRoundedWifiOff01,
        onRetry: onRetry,
      );
    }
    return InvestitureMessageState(
      key: key,
      title: title,
      body: investitureErrorMessage(error),
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
    final hasCustomAction = actionLabel != null && onAction != null;
    return Padding(
      padding: EdgeInsets.only(top: SacTopBar.frostedInset(context)),
      child: SacEmptyState(
        title: title,
        body: body,
        icon: icon,
        actionLabel: hasCustomAction
            ? actionLabel
            : (onRetry == null ? null : tr('common.retry')),
        onAction: hasCustomAction ? onAction : onRetry,
        actionIcon: hasCustomAction
            ? HugeIcons.strokeRoundedMedal01
            : HugeIcons.strokeRoundedRefresh,
        actionVariant: SacButtonVariant.outline,
      ),
    );
  }
}

/// ¿El error es de conectividad (sin red o tiempo agotado)?
bool isInvestitureOfflineError(Object? error) =>
    error is ConnectionFailure || error is NetworkFailure;
