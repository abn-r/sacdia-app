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
                child: const Text('Reintentar'),
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
          title: 'Ranking no disponible',
          body:
              'Tu director puede activar la visibilidad del ranking cuando esté listo.',
        );
      case RankingEmptyReason.noData:
        return _EmptyConfig(
          icon: HugeIcons.strokeRoundedClock01,
          title: 'Aún no hay datos',
          body:
              'Tu ranking se calcula automáticamente. Volvé a revisar más tarde.',
        );
      case RankingEmptyReason.networkError:
        return _EmptyConfig(
          icon: HugeIcons.strokeRoundedWifiDisconnected01,
          title: 'Sin conexión',
          body: 'No pudimos cargar tu ranking.',
        );
      case RankingEmptyReason.noSectionMembers:
        return _EmptyConfig(
          icon: HugeIcons.strokeRoundedUserSearch01,
          title: 'Todavía no hay rankings',
          body:
              'Los rankings se calculan automáticamente cada 24 hs. Las clases y camporees del año ya deben estar registrados.',
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
