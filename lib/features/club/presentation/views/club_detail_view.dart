import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../domain/entities/club_info.dart';
import '../providers/club_providers.dart';

/// Vista de solo lectura del detalle de un club contenedor.
///
/// Muestra la información básica del club identificado por [clubId] (UUID).
/// Ruta: /club/:clubId
class ClubDetailView extends ConsumerWidget {
  final String clubId;

  const ClubDetailView({super.key, required this.clubId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final clubAsync = ref.watch(clubInfoProvider(clubId));

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        foregroundColor: c.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: c.text,
            size: 22,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Volver',
        ),
        title: Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedBuilding01,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: 10),
            Text(
              'DETALLE DEL CLUB',
              style: TextStyle(
                color: c.text,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: c.border),
        ),
      ),
      body: clubAsync.when(
        loading: () => const Center(child: SacLoading()),
        error: (error, _) => _ErrorBody(
          message: error.toString().replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(clubInfoProvider(clubId)),
        ),
        data: (club) => _ClubDetailBody(club: club),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cuerpo principal
// ─────────────────────────────────────────────────────────────────────────────

class _ClubDetailBody extends StatelessWidget {
  final ClubInfo club;

  const _ClubDetailBody({required this.club});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Sección: Información general ──────────────────────────────────
        _SectionHeader(
          icon: HugeIcons.strokeRoundedInformationCircle,
          label: 'Información general',
        ),
        const SizedBox(height: 12),

        _InfoRow(
          icon: HugeIcons.strokeRoundedBuilding01,
          label: 'Nombre del club',
          value: club.name.isNotEmpty ? club.name : '—',
        ),

        const SizedBox(height: 16),

        _InfoRow(
          icon: HugeIcons.strokeRoundedCheckmarkCircle01,
          label: 'Estado',
          value: club.active ? 'Activo' : 'Inactivo',
          valueColor: club.active ? AppColors.secondary : AppColors.error,
        ),

        const SizedBox(height: 16),

        _InfoRow(
          icon: HugeIcons.strokeRoundedIdentification,
          label: 'ID del club',
          value: club.id,
        ),

        const SizedBox(height: 32),

        // Nota informativa
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedInformationCircle,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Para ver el detalle completo de las secciones del club '
                  '(Aventureros, Conquistadores, Guías Mayores) '
                  'accedé desde el módulo Mi Club.',
                  style: TextStyle(
                    fontSize: 13,
                    color: c.text,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets internos de apoyo
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final dynamic icon;
  final String label;

  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: HugeIcon(icon: icon, size: 16, color: AppColors.primary),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: c.text,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: c.divider, height: 1)),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final dynamic icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        boxShadow: [
          BoxShadow(
            color: c.shadow,
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 1),
            child: HugeIcon(icon: icon, size: 18, color: c.textSecondary),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: c.textTertiary,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: valueColor ?? c.text,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedAlert02,
              size: 56,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error al cargar el club',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(fontSize: 14, color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SacButton.primary(
              text: 'Reintentar',
              icon: HugeIcons.strokeRoundedRefresh,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
