import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_image_viewer.dart';
import '../../../members/presentation/providers/members_providers.dart'
    show ClubContext, clubContextProvider;
import '../../domain/entities/inventory_item.dart';
import '../providers/inventory_providers.dart';
import '../widgets/condition_badge.dart';
import 'add_inventory_item_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_back_button.dart';

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
    final detailAsync = ref.watch(inventoryItemDetailProvider(item.id));
    final detailItem = detailAsync.valueOrNull ?? item;
    final clubContext = ref.watch(clubContextProvider).valueOrNull;
    final clubTypeName = _clubTypeNameForItem(detailItem, clubContext);

    return Scaffold(
      backgroundColor: context.sac.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: sacAutoBackButton(context),
        backgroundColor: context.sac.background,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'inventory.detail.title'.tr(),
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
              isDeleting: deleteState.isLoading,
              onEdit: () => _openEdit(context, detailItem),
              onDelete: () => _confirmDelete(context, ref, detailItem),
            )
          : null,

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo hero — tag matches thumbnail tag in item card
            Hero(
              tag: 'inv-photo-${detailItem.id}',
              child: _PhotoSection(
                photoUrl: detailItem.photoUrl,
                imageUrls: detailItem.evidences.map((e) => e.url).toList(),
                title: detailItem.name,
              ),
            ),

            if (detailItem.evidences.isNotEmpty) ...[
              const SizedBox(height: 12),
              _EvidenceCard(
                itemName: detailItem.name,
                evidences: detailItem.evidences,
              ),
            ],

            const SizedBox(height: 20),

            // Title + condition badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    detailItem.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: context.sac.text,
                        ),
                  ),
                ),
                const SizedBox(width: 12),
                ConditionBadge(condition: detailItem.condition),
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
                detailItem.category.name,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),

            if (detailItem.description != null &&
                detailItem.description!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                detailItem.description!,
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
                  label: 'inventory.detail.quantity'.tr(),
                  value: detailItem.quantity.toString(),
                ),
                _InfoRow(
                  icon: HugeIcons.strokeRoundedTag01,
                  label: 'inventory.detail.category'.tr(),
                  value: detailItem.category.name,
                ),
                _InfoRow(
                  icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                  label: 'inventory.detail.condition'.tr(),
                  value: detailItem.condition.label,
                  valueColor: _conditionColor(detailItem.condition),
                ),
                _InfoRow(
                  icon: HugeIcons.strokeRoundedImage01,
                  label: 'inventory.detail.evidences'.tr(),
                  value: 'inventory.detail.evidence_count_value'.tr(
                    namedArgs: {
                      'count': detailItem.evidences.length.toString(),
                    },
                  ),
                ),
                if (clubTypeName != null)
                  _InfoRow(
                    icon: HugeIcons.strokeRoundedHome01,
                    label: 'inventory.detail.club_type'.tr(),
                    value: clubTypeName,
                  ),
                _InfoRow(
                  icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                  label: 'inventory.detail.record_status'.tr(),
                  value: detailItem.isActive
                      ? 'inventory.detail.active_status'.tr()
                      : 'inventory.detail.inactive_status'.tr(),
                  valueColor: detailItem.isActive
                      ? AppColors.secondary
                      : AppColors.error,
                ),
                if (detailItem.serialNumber != null &&
                    detailItem.serialNumber!.isNotEmpty)
                  _InfoRow(
                    icon: HugeIcons.strokeRoundedTag01,
                    label: 'inventory.detail.serial_number'.tr(),
                    value: detailItem.serialNumber!,
                  ),
                if (detailItem.purchaseDate != null)
                  _InfoRow(
                    icon: HugeIcons.strokeRoundedCalendar01,
                    label: 'inventory.detail.purchase_date'.tr(),
                    value: DateFormat('dd/MM/yyyy')
                        .format(detailItem.purchaseDate!.toLocal()),
                  ),
                if (detailItem.estimatedValue != null)
                  _InfoRow(
                    icon: HugeIcons.strokeRoundedMoney01,
                    label: 'inventory.detail.estimated_value'.tr(),
                    value: '\$${detailItem.estimatedValue!.toStringAsFixed(2)}',
                    valueColor: AppColors.secondary,
                  ),
              ],
            ),

            if (detailItem.location != null ||
                detailItem.assignedTo != null) ...[
              const SizedBox(height: 12),
              _InfoCard(
                children: [
                  if (detailItem.location != null &&
                      detailItem.location!.isNotEmpty)
                    _InfoRow(
                      icon: HugeIcons.strokeRoundedLocation01,
                      label: 'inventory.detail.location'.tr(),
                      value: detailItem.location!,
                    ),
                  if (detailItem.assignedTo != null &&
                      detailItem.assignedTo!.isNotEmpty)
                    _InfoRow(
                      icon: HugeIcons.strokeRoundedUser,
                      label: 'inventory.detail.assigned_to'.tr(),
                      value: detailItem.assignedTo!,
                    ),
                ],
              ),
            ],

            if (detailItem.notes != null && detailItem.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _InfoCard(
                children: [
                  _InfoRow(
                    icon: HugeIcons.strokeRoundedNote01,
                    label: 'inventory.detail.notes'.tr(),
                    value: detailItem.notes!,
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
                  leading: _ActorAvatar(
                    imageUrl: detailItem.registeredByAvatarUrl,
                  ),
                  label: 'inventory.detail.registered_by'.tr(),
                  value: detailItem.registeredByName,
                ),
                _InfoRow(
                  icon: HugeIcons.strokeRoundedCalendar01,
                  label: 'inventory.detail.registered_at'.tr(),
                  value: _formatDateTime(detailItem.registeredAt),
                ),
                if (detailItem.modifiedAt != null ||
                    detailItem.modifiedByName != null)
                  _InfoRow(
                    icon: HugeIcons.strokeRoundedEdit01,
                    label: 'inventory.detail.last_modified'.tr(),
                    value: _joinNonEmpty([
                      detailItem.modifiedByName,
                      detailItem.modifiedAt != null
                          ? _formatDateTime(detailItem.modifiedAt!)
                          : null,
                    ]),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openEdit(BuildContext context, InventoryItem selectedItem) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddInventoryItemSheet(existing: selectedItem),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    InventoryItem selectedItem,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('inventory.detail.delete_title'.tr()),
        content: Text('inventory.detail.delete_confirm'
            .tr(namedArgs: {'name': selectedItem.name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref
                  .read(inventoryDeleteNotifierProvider.notifier)
                  .deleteItem(selectedItem.id);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('inventory.detail.deleted_success'.tr()),
                    backgroundColor: AppColors.secondary,
                  ),
                );
                Navigator.pop(context);
              } else if (!success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('inventory.detail.delete_error'.tr()),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );
  }
}

Color _conditionColor(ItemCondition condition) {
  switch (condition) {
    case ItemCondition.bueno:
      return AppColors.secondary;
    case ItemCondition.regular:
      return AppColors.warning;
    case ItemCondition.malo:
      return AppColors.error;
  }
}

String _formatDateTime(DateTime value) {
  return DateFormat('dd/MM/yyyy HH:mm').format(value.toLocal());
}

String? _clubTypeNameForItem(InventoryItem item, ClubContext? context) {
  final clubTypeName = context?.clubTypeName?.trim();
  if (clubTypeName == null || clubTypeName.isEmpty) return null;
  if (item.clubSectionId != null && item.clubSectionId != context?.sectionId) {
    return null;
  }
  return clubTypeName;
}

String _joinNonEmpty(List<String?> values) {
  return values
      .where((value) => value != null && value.trim().isNotEmpty)
      .map((value) => value!.trim())
      .join(' · ');
}

// ── Bottom action bar ───────────────────────────────────────────────────────────

class _BottomActionBar extends StatelessWidget {
  final bool isDeleting;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BottomActionBar({
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
              child: SizedBox(
                height: 56,
                child: OutlinedButton(
                  onPressed: isDeleting ? null : onDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                    ),
                  ),
                  child: _ActionButtonLabel(
                    icon: isDeleting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
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
                    label: 'common.delete'.tr(),
                    color: AppColors.error,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Edit button
            Expanded(
              child: SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: onEdit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                    ),
                  ),
                  child: _ActionButtonLabel(
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedEdit01,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: 'inventory.detail.edit_button'.tr(),
                    color: Colors.white,
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

class _ActionButtonLabel extends StatelessWidget {
  final Widget icon;
  final String label;
  final Color color;

  const _ActionButtonLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
      ],
    );
  }
}

// ── Photo section ───────────────────────────────────────────────────────────────

class _PhotoSection extends StatelessWidget {
  final String? photoUrl;
  final List<String> imageUrls;
  final String title;

  const _PhotoSection({
    this.photoUrl,
    this.imageUrls = const [],
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      final urls = imageUrls.isNotEmpty ? imageUrls : [photoUrl!];

      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => SacImageViewer.show(
            context,
            imageUrl: photoUrl!,
            imageUrls: urls,
            title: title,
          ),
          borderRadius: BorderRadius.circular(20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: CachedNetworkImage(
              imageUrl: photoUrl!,
              width: double.infinity,
              height: 220,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const _PhotoPlaceholder(),
            ),
          ),
        ),
      );
    }
    return const _PhotoPlaceholder();
  }
}

class _EvidenceCard extends StatelessWidget {
  final String itemName;
  final List<InventoryEvidence> evidences;

  const _EvidenceCard({
    required this.itemName,
    required this.evidences,
  });

  @override
  Widget build(BuildContext context) {
    final urls = evidences.map((e) => e.url).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.sac.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: context.sac.border.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedImage01,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'inventory.detail.evidence_title'.tr(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: context.sac.text,
                      ),
                ),
              ),
              Text(
                'inventory.detail.evidence_count_value'.tr(
                  namedArgs: {'count': evidences.length.toString()},
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.sac.textTertiary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var index = 0; index < evidences.length; index++)
                _EvidenceThumb(
                  url: evidences[index].url,
                  onTap: () => SacImageViewer.show(
                    context,
                    imageUrl: evidences[index].url,
                    imageUrls: urls,
                    initialIndex: index,
                    title: itemName,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EvidenceThumb extends StatelessWidget {
  final String url;
  final VoidCallback onTap;

  const _EvidenceThumb({
    required this.url,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            color: context.sac.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedImageNotFound01,
                  size: 22,
                  color: context.sac.textTertiary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
            'inventory.detail.no_photo'.tr(),
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
  final List<List<dynamic>> icon;
  final Widget? leading;
  final String label;
  final String value;
  final Color? valueColor;
  final bool isMultiline;

  const _InfoRow({
    required this.icon,
    this.leading,
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
          leading ??
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

class _ActorAvatar extends StatelessWidget {
  final String? imageUrl;

  const _ActorAvatar({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = imageUrl?.trim();
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return HugeIcon(
        icon: HugeIcons.strokeRoundedUser,
        size: 18,
        color: context.sac.textSecondary,
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: avatarUrl,
        width: 28,
        height: 28,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => HugeIcon(
          icon: HugeIcons.strokeRoundedUser,
          size: 18,
          color: context.sac.textSecondary,
        ),
        placeholder: (_, __) => Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.sac.surfaceVariant,
          ),
          child: SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.sac.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}
