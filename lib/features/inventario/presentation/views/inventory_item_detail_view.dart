import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/inventory_item.dart';
import '../providers/inventario_providers.dart';
import '../widgets/condition_badge.dart';
import 'add_inventory_item_sheet.dart';

/// Pantalla de detalle de un ítem del inventario.
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
        actions: [
          if (canManage)
            IconButton(
              onPressed: deleteState.isLoading
                  ? null
                  : () => _confirmDelete(context, ref),
              icon: deleteState.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.error),
                    )
                  : HugeIcon(
                      icon: HugeIcons.strokeRoundedDelete02,
                      size: 22,
                      color: AppColors.error,
                    ),
            ),
          if (canManage)
            IconButton(
              onPressed: () => _openEdit(context),
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedEdit01,
                size: 22,
                color: context.sac.textSecondary,
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo hero
            _PhotoSection(photoUrl: item.photoUrl),

            const SizedBox(height: 20),

            // Title + condition
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

            // Category
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

            if (item.description != null && item.description!.isNotEmpty) ...[
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

            // Info cards
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
                    value: DateFormat('dd/MM/yyyy').format(item.purchaseDate!),
                  ),
                if (item.estimatedValue != null)
                  _InfoRow(
                    icon: HugeIcons.strokeRoundedMoney01,
                    label: 'Valor estimado',
                    value:
                        '\$${item.estimatedValue!.toStringAsFixed(2)}',
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
                      '${item.registeredByName} · ${DateFormat('dd/MM/yyyy').format(item.registeredAt)}',
                ),
                if (item.modifiedByName != null)
                  _InfoRow(
                    icon: HugeIcons.strokeRoundedEdit01,
                    label: 'Última modificación',
                    value:
                        '${item.modifiedByName} · ${item.modifiedAt != null ? DateFormat('dd/MM/yyyy').format(item.modifiedAt!) : ''}',
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
              }
            },
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
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
        child: Image.network(
          photoUrl!,
          width: double.infinity,
          height: 220,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _Placeholder(),
        ),
      );
    }
    return _Placeholder();
  }
}

class _Placeholder extends StatelessWidget {
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
            size: 56,
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
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
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
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
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
  final List<List<dynamic>> icon;
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
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                        fontSize: 11,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: valueColor,
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
