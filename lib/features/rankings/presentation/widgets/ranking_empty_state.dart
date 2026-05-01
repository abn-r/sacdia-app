import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';

/// Razones por las que el ranking no se puede mostrar.
enum RankingEmptyReason {
  /// Visibilidad configurada como "oculto" por el director.
  hidden,

  /// Datos aún no calculados.
  noData,

  /// Error de red al cargar el ranking.
  networkError,

  /// Sección sin miembros suficientes para calcular rankings.
  noSectionMembers,

  /// Usuario sin permisos para ver el ranking de esta sección (RBAC).
  unauthorized,
}

/// Estado vacío genérico para el ranking, dirigido por [RankingEmptyReason].
///
/// Reutilizable por Task 25 (MyRankingScreen) y Task 26 (SectionRankingScreen).
class RankingEmptyState extends StatelessWidget {
  final RankingEmptyReason reason;

  /// Callback solo usado para [RankingEmptyReason.networkError].
  final VoidCallback? onRetry;

  const RankingEmptyState({
    super.key,
    required this.reason,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final config = _configFor(reason);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: config.icon,
              size: 64,
              color: c.textTertiary,
            ),
            const SizedBox(height: 20),
            Text(
              config.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: c.text,
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              config.body,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: c.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            if (reason == RankingEmptyReason.networkError &&
                onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(88, 44),
                ),
                child: Text(tr('rankings.empty_state.retry')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  _EmptyConfig _configFor(RankingEmptyReason reason) {
    switch (reason) {
      case RankingEmptyReason.hidden:
        return _EmptyConfig(
          icon: HugeIcons.strokeRoundedViewOff,
          title: tr('rankings.empty_state.unavailable_title'),
          body: tr('rankings.empty_state.unavailable_subtitle'),
        );
      case RankingEmptyReason.noData:
        return _EmptyConfig(
          icon: HugeIcons.strokeRoundedClock01,
          title: tr('rankings.empty_state.no_data_title'),
          body: tr('rankings.empty_state.no_data_subtitle'),
        );
      case RankingEmptyReason.networkError:
        return _EmptyConfig(
          icon: HugeIcons.strokeRoundedWifiDisconnected01,
          title: tr('rankings.empty_state.network_error_title'),
          body: tr('rankings.empty_state.network_error_subtitle'),
        );
      case RankingEmptyReason.noSectionMembers:
        return _EmptyConfig(
          icon: HugeIcons.strokeRoundedUserSearch01,
          title: tr('rankings.empty_state.no_members_title'),
          body: tr('rankings.empty_state.no_members_subtitle'),
        );
      case RankingEmptyReason.unauthorized:
        return _EmptyConfig(
          icon: HugeIcons.strokeRoundedShieldKey,
          title: tr('rankings.empty_state.unauthorized_title'),
          body: tr('rankings.empty_state.unauthorized_subtitle'),
        );
    }
  }
}

class _EmptyConfig {
  final HugeIconData icon;
  final String title;
  final String body;

  const _EmptyConfig({
    required this.icon,
    required this.title,
    required this.body,
  });
}
