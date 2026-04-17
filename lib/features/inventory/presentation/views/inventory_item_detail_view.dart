import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../domain/entities/inventory_item.dart';
import '../providers/inventory_providers.dart';
import '../widgets/condition_badge.dart';
import 'add_inventory_item_sheet.dart';

/// Pantalla de detalle de un ítem del inventario.
///
/// Botones de editar/eliminar en la zona del pulgar (barra inferior),
/// no en el AppBar. Hero animation en la foto desde la lista.
class InventoryItemDetailView extends ConsumerWidget {
  final InventoryItem item;

  const InventoryItemDetailView({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManageAsync = ref.watch(canManageInventoryProvider);
    final canManage = canManageAsync.valueOrNull ?? false;
    final deleteState = ref.watch(inventoryDeleteNotifierProvider);

    return Scaffold(
      backgroundColor: context.sac.background,
      appBar: AppBar(
        backgroundColor: context.sac.background,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Detalle del Artículo',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.sac.text,
              ),
        ),
        centerTitle: false,
      ),

      // Action bar at bottom — thumb zone
      bottomNavigationBar: canManage
          ? _BottomActionBar(
              item: item,
              isDeleting: deleteState.isLoading,
              onEdit: () => _openEdit(context),
              onDelete: () => _confirmDelete(context, ref),
            )
          : null,

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo hero — tag matches thumbnail tag in item card
            Hero(
              tag: 'inv-photo-${item.id}',
              child: _PhotoSection(photoUrl: item.photoUrl),
            ),

            const SizedBox(height: 20),

            // Title + condition badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style:
                        Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: context.sac.text,
                            ),
                  ),
                ),
                const SizedBox(width: 12),
                ConditionBadge(condition: item.condition),
              ],
            ),

            const SizedBox(height: 8),

            // Category tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                item.category.name,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),

            if (item.description != null &&
                item.description!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                item.description!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.sac.textSecondary,
                      height: 1.5,
                    ),
              ),
            ],

            const SizedBox(height: 20),

            // Primary info card
            _InfoCard(
              children: [
                _InfoRow(
                  icon: HugeIcons.strokeRoundedPackage,
                  label: 'Cantidad',
                  value: item.quantity.toString(),
                ),
                if (item.serialNumber != null &&
                    item.serialNumber!.isNotEmpty)
                  _InfoRow(
                    icon: HugeIcons.strokeRoundedTag01,
                    label: 'N. de serie / código',
                    value: item.serialNumber!,
                  ),
                if (item.purchaseDate != null)
                  _InfoRow(
                    icon: HugeIcons.strokeRoundedCalendar01,
                    label: 'Fecha de adquisición',
                    value: DateFormat('dd/MM/yyyy')
                        .format(item.purchaseDate!.toLocal()),
                  ),
                if (item.estimatedValue != null)
                  _InfoRow(
                    icon: HugeIcons.strokeRoundedMoney01,
                    label: 'Valor estimado',
                    value: '\$${item.estimatedValue!.toStringAsFixed(2)}',
                    valueColor: AppColors.secondary,
                  ),
              ],
            ),

            if (item.location != null || item.assignedTo != null) ...[
              const SizedBox(height: 12),
              _InfoCard(
                children: [
                  if (item.location != null && item.location!.isNotEmpty)
                    _InfoRow(
                      icon: HugeIcons.strokeRoundedLocation01,
                      label: 'Ubicación',
                      value: item.location!,
                    ),
                  if (item.assignedTo != null &&
                      item.assignedTo!.isNotEmpty)
                    _InfoRow(
                      icon: HugeIcons.strokeRoundedUser,
                      label: 'Asignado a',
                      value: item.assignedTo!,
                    ),
                ],
              ),
            ],

            if (item.notes != null && item.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _InfoCard(
                children: [
                  _InfoRow(
                    icon: HugeIcons.strokeRoundedNote01,
                    label: 'Notas',
                    value: item.notes!,
                    isMultiline: true,
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            // Audit trail
            _InfoCard(
              children: [
                _InfoRow(
                  icon: HugeIcons.strokeRoundedUser,
                  label: 'Registrado por',
                  value:
                      '${item.registeredByName} · ${DateFormat('dd/MM/yyyy').format(item.registeredAt.toLocal())}',
                ),
                if (item.modifiedByName != null)
                  _InfoRow(
                    icon: HugeIcons.strokeRoundedEdit01,
                    label: 'Última modificación',
                    value:
                        '${item.modifiedByName} · ${item.modifiedAt != null ? DateFormat('dd/MM/yyyy').format(item.modifiedAt!.toLocal()) : ''}',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openEdit(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddInventoryItemSheet(existing: item),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar artículo'),
        content: Text(
            '¿Estás seguro de que deseas eliminar "${item.name}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref
                  .read(inventoryDeleteNotifierProvider.notifier)
                  .deleteItem(item.id);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Artículo eliminado correctamente'),
                    backgroundColor: AppColors.secondary,
                  ),
                );
                Navigator.pop(context);
              } else if (!success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No se pudo eliminar el artículo'),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

// ── Bottom action bar ───────────────────────────────────────────────────────────

class _BottomActionBar extends StatelessWidget {
  final InventoryItem item;
  final bool isDeleting;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BottomActionBar({
    required this.item,
    required this.isDeleting,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: context.sac.surface,
          border: Border(top: BorderSide(color: context.sac.border)),
        ),
        child: Row(
          children: [
            // Delete button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isDeleting ? null : onDelete,
                icon: isDeleting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.error,
                        ),
                      )
                    : const HugeIcon(
                        icon: HugeIcons.strokeRoundedDelete02,
                        size: 18,
                        color: AppColors.error,
                      ),
                label: const Text('Eliminar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Edit button
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: onEdit,
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedEdit01,
                  size: 18,
                  color: Colors.white,
                ),
                label: const Text('Editar artículo'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Photo section ───────────────────────────────────────────────────────────────

class _PhotoSection extends StatelessWidget {
  final String? photoUrl;

  const _PhotoSection({this.photoUrl});

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: CachedNetworkImage(
          imageUrl: photoUrl!,
          width: double.infinity,
          height: 220,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => const _PhotoPlaceholder(),
        ),
      );
    }
    return const _PhotoPlaceholder();
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedBoxingBag,
            size: 52,
            color: AppColors.primary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 8),
          Text(
            'Sin foto',
            style: TextStyle(
              color: AppColors.primary.withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info card ───────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final List<Widget> children;

  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.sac.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: context.sac.border.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        children: List.generate(children.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Divider(
              height: 1,
              thickness: 0.5,
              indent: 16,
              endIndent: 16,
              color: context.sac.border.withValues(alpha: 0.5),
            );
          }
          return children[i ~/ 2];
        }),
      ),
    );
  }
}

// ── Info row ────────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final HugeIconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool isMultiline;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.isMultiline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment:
            isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          HugeIcon(
            icon: icon,
            size: 18,
            color: context.sac.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.sac.textTertiary,
                        fontSize: 11,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: valueColor ?? context.sac.text,
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
